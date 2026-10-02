import AppKit
import SwiftUI

/// Shows a welcome panel every time the app starts. The full glow sequence is
/// reserved for the first launch (and for an explicit replay from Settings).
///
/// The sequence only plays on the primary screen. If the screen topology
/// changes mid-sequence we cancel rather than migrate — a missed show is
/// cheaper than a misplaced one.
@MainActor
final class OnboardingCoordinator {
    static let replayRequestedNotification = Notification.Name(
        "com.notchtoolbox.onboarding.replayRequested"
    )

    /// Delay the full first-launch sequence until the shell and menu bar have
    /// settled. Later launches skip the glow and can show their greeting as
    /// soon as the panel system is ready.
    private static let firstLaunchDelay: Duration = .seconds(1.5)

    private let compositionRoot: AppCompositionRoot
    private let settingsStore: SettingsStore
    private let topologyProvider: DisplayTopologyProviding
    private let profileResolver = ScreenProfileResolver()
    private let glowController = OnboardingGlowWindowController()
    private var firstLaunchTask: Task<Void, Never>?
    private var replayObserver: NSObjectProtocol?
    private var screenChangeObserver: NSObjectProtocol?

    /// Moves the overlay panel system's active screen to the glow's target
    /// screen so the welcome mini panel appears where the glow converges.
    var activateScreen: ((String) -> Void)?

    init(
        compositionRoot: AppCompositionRoot,
        topologyProvider: DisplayTopologyProviding
    ) {
        self.compositionRoot = compositionRoot
        self.settingsStore = compositionRoot.sharedServices.settingsStore
        self.topologyProvider = topologyProvider
    }

    func start() {
        compositionRoot.restVariantContentRegistry.register(
            AnyRestVariantContentProvider(
                moduleID: OnboardingWelcomePresentation.moduleID
            ) { _, appearance, _ in
                OnboardingWelcomeRestVariantContentView(appearance: appearance)
            }
        )
        replayObserver = NotificationCenter.default.addObserver(
            forName: Self.replayRequestedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
        }
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancelIfPlaying()
            }
        }

        // The first run deliberately waits for the edge-glow stage. On later
        // app launches, enqueue the same greeting panel immediately: this is
        // both more responsive and avoids a brief, invisible wait while the
        // app is still an accessory application with no ordinary window.
        guard settingsStore.settings.hasCompletedOnboarding == false else {
            showWelcomePanel()
            return
        }

        firstLaunchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.firstLaunchDelay)
            guard Task.isCancelled == false, let self else {
                return
            }

            playWelcome(withGlow: true)
        }
    }

    func play() {
        playWelcome(withGlow: true)
    }

    private func playWelcome(withGlow: Bool) {
        guard glowController.isPlaying == false else {
            return
        }

        let profiles = topologyProvider.currentSnapshots().map {
            profileResolver.resolve(
                snapshot: $0,
                simulateNotchOnNonNotchScreen: settingsStore.settings.simulateNotchOnNonNotchScreen
            )
        }
        // "Primary" for onboarding means the screen the notch story belongs
        // to: hardware notch first, then the built-in screen, then whatever
        // the topology provider ranks first (NSScreen.main can be an external
        // display when another app holds key focus at launch). The welcome
        // panel is activated here, but the glow now plays on every screen so it
        // matches the welcome notch appearing on all of them.
        guard let primaryProfile = profiles.first(where: \.supportsHardwareNotch)
            ?? profiles.first(where: { $0.kind == .builtInWithoutNotch })
            ?? profiles.first else {
            return
        }

        activateScreen?(primaryProfile.id)
        if withGlow {
            markCompleted()
            glowController.play(
                contexts: profiles.map(glowContext(for:)),
                onWelcomeMoment: { [weak self] in
                    self?.showWelcomePanel()
                },
                completion: {
                    // One-shot; nothing to clean up beyond the window itself.
                }
            )
        } else {
            showWelcomePanel()
        }
    }

    private func showWelcomePanel() {
        compositionRoot.restVariantStore.enqueueTransientRequest(
            OnboardingWelcomePresentation.transientRequest()
        )
    }

    private func cancelIfPlaying() {
        guard glowController.isPlaying else {
            return
        }

        glowController.cancel()
    }

    private func glowContext(for profile: ScreenProfile) -> OnboardingGlowContext {
        let notchMetrics = profile.notchMetrics ?? NotchMetrics.fallback

        return OnboardingGlowContext(
            screenFrame: profile.frame,
            anchorWidth: notchMetrics.visibleSize.width,
            scaleFactor: profile.scaleFactor
        )
    }

    private func markCompleted() {
        guard settingsStore.settings.hasCompletedOnboarding == false else {
            return
        }

        try? settingsStore.update { settings in
            settings.hasCompletedOnboarding = true
        }
    }

    deinit {
        firstLaunchTask?.cancel()
        if let replayObserver {
            NotificationCenter.default.removeObserver(replayObserver)
        }
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }
}
