import Foundation
import SwiftUI

/// Welcome greeting shown during onboarding as a standard
/// `headerlessMiniPanel` rest variant — same shell chrome, drop animation
/// and lifecycle as the pomodoro finished toast.
enum OnboardingWelcomePresentation {
    /// Registry slot for the welcome content. Onboarding is app-level and
    /// owns no module; `.settings` is the closest app-level module and
    /// declares no rest variants of its own.
    static let moduleID: NotchModuleID = .settings

    static let width: CGFloat = 340
    static let height: CGFloat = 96
    /// Keeps the greeting below the hardware notch, mirroring the pomodoro
    /// toast's top inset rule.
    static let contentTop: CGFloat = 36
    static let contentHeight: CGFloat = 24
    static let fontSize: CGFloat = 15
    static let duration: Duration = .seconds(3)

    /// A time-aware Chinese greeting. We deliberately use the user's current
    /// calendar and time zone so it feels local without collecting any data.
    static func greeting(at date: Date = .now, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12:
            return "早上好"
        case 12..<18:
            return "下午好"
        default:
            return "晚上好"
        }
    }

    static func transientRequest() -> RestVariantRequest {
        RestVariantRequest(
            moduleID: moduleID,
            kind: .headerlessMiniPanel,
            preferredWidth: width,
            preferredHeight: height,
            lifetime: .transient(
                token: UUID(),
                duration: duration,
                declaredAt: Date()
            ),
            // The greeting is a one-shot announcement, not an entry point:
            // during onboarding it must not expand on click. Once it retracts
            // the panel returns to the normal clickable idle state.
            isInteractive: false
        )
    }
}

struct OnboardingWelcomeRestVariantContentView: View {
    let appearance: OverlayPanelCollapsedAppearance

    var body: some View {
        switch appearance {
        case .headerlessMiniPanel:
            Text("👋 \(OnboardingWelcomePresentation.greeting())")
                .font(.system(size: OnboardingWelcomePresentation.fontSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .frame(
                    width: OnboardingWelcomePresentation.width,
                    height: OnboardingWelcomePresentation.contentHeight,
                    alignment: .center
                )
                .padding(.top, OnboardingWelcomePresentation.contentTop)
                .frame(
                    width: OnboardingWelcomePresentation.width,
                    height: OnboardingWelcomePresentation.height,
                    alignment: .top
                )
        case .wideNotchStrip, .transparent:
            EmptyView()
        }
    }
}
