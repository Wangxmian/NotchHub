import AppKit
import SwiftUI
import Testing
@testable import NotchToolbox

@MainActor
struct SettingsFeedbackTests {
    @Test func feedbackContactExposesTheSupportAddress() {
        #expect(SettingsFeedbackContact.feedbackAddress == "https://github.com/Wangxmian/NotchHub/issues")
    }

    @Test func copyingFeedbackEmailPutsPlainTextOnThePasteboard() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(rawValue: "com.notch.tests.feedback"))
        pasteboard.clearContents()
        pasteboard.setString("stale", forType: .string)

        let copied = SettingsFeedbackContact.copyFeedbackAddress(to: pasteboard)

        #expect(copied)
        #expect(pasteboard.string(forType: .string) == SettingsFeedbackContact.feedbackAddress)
    }

    // The copy confirmation reuses the shared panel toast so feedback looks the same
    // everywhere in the app — green, with a checkmark.
    @Test func copyConfirmationShowsGreenSuccessToast() {
        let presenter = PanelToastPresenter()

        presenter.show(SettingsFeedbackContact.copiedToastText, emphasis: .success)

        #expect(presenter.toast?.text == "复制成功")
        #expect(presenter.toast?.emphasis == .success)
    }

    @Test func successEmphasisIsGreenAndDistinctFromErrorAndInfo() {
        #expect(PanelToastEmphasis.success.glyph == "checkmark.circle.fill")

        let success = NSColor(PanelToastEmphasis.success.tint).usingColorSpace(.deviceRGB)
        let successGreen = try! #require(success).greenComponent
        let successRed = try! #require(success).redComponent
        #expect(successGreen > successRed)

        #expect(PanelToastEmphasis.success.tint != PanelToastEmphasis.error.tint)
        #expect(PanelToastEmphasis.success.tint != PanelToastEmphasis.info.tint)
    }
}
