import AppKit

nonisolated enum ClipboardAction: Equatable { case copy, copyPlainText, paste, pastePlainText }
nonisolated enum ClipboardActionResolver {
    static func resolve(_ flags: NSEvent.ModifierFlags, preferences p: ClipboardPreferences) -> ClipboardAction? {
        let f = flags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        if f.isEmpty { return p.pasteByDefault ? (p.removeFormattingByDefault ? .pastePlainText : .paste) : (p.removeFormattingByDefault ? .copyPlainText : .copy) }
        if f == .command { return p.pasteByDefault ? (p.removeFormattingByDefault ? .pastePlainText : .paste) : .copy }
        if f == .option { return p.pasteByDefault ? .copy : (p.removeFormattingByDefault ? .pastePlainText : .paste) }
        if f == [.option, .shift], !p.pasteByDefault { return p.removeFormattingByDefault ? .paste : .pastePlainText }
        if f == [.command, .shift], p.pasteByDefault { return p.removeFormattingByDefault ? .paste : .pastePlainText }
        return nil
    }
}
