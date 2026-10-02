import Carbon
import Foundation
import ServiceManagement

@MainActor
protocol GlobalShortcutServicing: AnyObject {
    var registeredShortcut: KeyboardShortcutDescriptor? { get }

    func register(
        _ shortcut: KeyboardShortcutDescriptor,
        handler: @escaping @MainActor () -> Void
    ) throws
    func unregister()
}

@MainActor
final class InMemoryGlobalShortcutService: GlobalShortcutServicing {
    private(set) var registeredShortcut: KeyboardShortcutDescriptor?
    private var handler: (@MainActor () -> Void)?

    func register(
        _ shortcut: KeyboardShortcutDescriptor,
        handler: @escaping @MainActor () -> Void
    ) throws {
        registeredShortcut = shortcut
        self.handler = handler
    }

    func unregister() {
        registeredShortcut = nil
        handler = nil
    }

    func trigger() {
        handler?()
    }
}

@MainActor
final class CarbonGlobalShortcutService: GlobalShortcutServicing {
    private(set) var registeredShortcut: KeyboardShortcutDescriptor?
    private var handler: (@MainActor () -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let identifier: UInt32
    init(identifier: UInt32 = 1) { self.identifier = identifier }

    func register(
        _ shortcut: KeyboardShortcutDescriptor,
        handler: @escaping @MainActor () -> Void
    ) throws {
        unregister()

        let keyCode = try KeyboardShortcutCarbonMapper.keyCode(for: shortcut.keyEquivalent)
        let modifiers = KeyboardShortcutCarbonMapper.modifiers(for: shortcut.modifiers)
        var hotKeyID = EventHotKeyID(
            signature: KeyboardShortcutCarbonMapper.signature,
            id: identifier
        )
        var nextHotKeyRef: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &nextHotKeyRef
        )
        guard registerStatus == noErr else {
            throw GlobalShortcutError.registrationFailed(status: registerStatus)
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var nextEventHandlerRef: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let userData else {
                    return noErr
                }

                let service = Unmanaged<CarbonGlobalShortcutService>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                var received = EventHotKeyID()
                guard let event, GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &received) == noErr,
                      received.signature == KeyboardShortcutCarbonMapper.signature,
                      received.id == service.identifier else { return OSStatus(eventNotHandledErr) }
                Task { @MainActor in
                    service.handler?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &nextEventHandlerRef
        )
        guard installStatus == noErr else {
            if let nextHotKeyRef {
                UnregisterEventHotKey(nextHotKeyRef)
            }
            throw GlobalShortcutError.eventHandlerInstallFailed(status: installStatus)
        }

        self.hotKeyRef = nextHotKeyRef
        self.eventHandlerRef = nextEventHandlerRef
        self.registeredShortcut = shortcut
        self.handler = handler
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        hotKeyRef = nil
        eventHandlerRef = nil
        registeredShortcut = nil
        handler = nil
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

enum GlobalShortcutError: Error, Equatable {
    case unsupportedKey(String)
    case registrationFailed(status: OSStatus)
    case eventHandlerInstallFailed(status: OSStatus)
}

enum KeyboardShortcutCarbonMapper {
    static let signature: OSType = 0x4E544348

    static func keyCode(for keyEquivalent: String) throws -> UInt32 {
        guard let character = keyEquivalent.lowercased().first else {
            throw GlobalShortcutError.unsupportedKey(keyEquivalent)
        }

        if let code = currentLayoutKeyCode(String(character)) { return code }
        guard let code = keyCodes[character] else {
            throw GlobalShortcutError.unsupportedKey(keyEquivalent)
        }

        return code
    }

    static func currentLayoutKeyCode(_ character: String) -> UInt32? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        for code in UInt16(0)...UInt16(127) {
            var state: UInt32 = 0; var count = 0; var buffer = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &state, buffer.count, &count, &buffer)
            if status == noErr && String(utf16CodeUnits: buffer, count: count).lowercased() == character.lowercased() { return UInt32(code) }
        }
        return nil
    }
    static var commandSwitchesToQWERTY: Bool {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(), let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
        let value = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
        return value.lowercased().contains("dvorak-qwerty")
    }

    static func modifiers(for modifiers: [ShortcutModifier]) -> UInt32 {
        modifiers.reduce(UInt32(0)) { result, modifier in
            switch modifier {
            case .command:
                return result | UInt32(cmdKey)
            case .option:
                return result | UInt32(optionKey)
            case .control:
                return result | UInt32(controlKey)
            case .shift:
                return result | UInt32(shiftKey)
            }
        }
    }

    static func canMap(_ shortcut: KeyboardShortcutDescriptor) -> Bool {
        (try? keyCode(for: shortcut.keyEquivalent)) != nil
    }

    private static let keyCodes: [Character: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
        "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50
    ]
}

enum KeyboardShortcutConflictValidator {
    static func isAvailable(_ shortcut: KeyboardShortcutDescriptor) -> Bool {
        do {
            let keyCode = try KeyboardShortcutCarbonMapper.keyCode(for: shortcut.keyEquivalent)
            let modifiers = KeyboardShortcutCarbonMapper.modifiers(for: shortcut.modifiers)
            var hotKeyID = EventHotKeyID(
                signature: KeyboardShortcutCarbonMapper.signature,
                id: 999
            )
            var hotKeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &hotKeyRef
            )
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
            return status == noErr
        } catch {
            return false
        }
    }
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
    var isEnabled: Bool { get }

    func setEnabled(_ enabled: Bool) throws
}

@MainActor
final class InMemoryLaunchAtLoginService: LaunchAtLoginServicing {
    private(set) var isEnabled = false

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}

// Thin seam over the single system call so the enable/disable branching in
// SMAppServiceLaunchAtLoginService stays unit-testable without touching the
// real login-item database.
@MainActor
protocol LoginItemRegistering: AnyObject {
    var isRegistered: Bool { get }

    func register() throws
    func unregister() throws
}

@MainActor
final class SMAppServiceLoginItemRegistrar: LoginItemRegistering {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var isRegistered: Bool {
        service.status == .enabled
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}

@MainActor
final class SMAppServiceLaunchAtLoginService: LaunchAtLoginServicing {
    private let registrar: any LoginItemRegistering

    init(registrar: (any LoginItemRegistering)? = nil) {
        self.registrar = registrar ?? SMAppServiceLoginItemRegistrar()
    }

    var isEnabled: Bool {
        registrar.isRegistered
    }

    func setEnabled(_ enabled: Bool) throws {
        // Registering an already-enabled item (or unregistering a disabled one)
        // throws with SMAppService, so gate on current status to keep the
        // operation idempotent.
        guard registrar.isRegistered != enabled else {
            return
        }

        if enabled {
            try registrar.register()
        } else {
            try registrar.unregister()
        }
    }
}
