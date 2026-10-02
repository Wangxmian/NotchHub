import SwiftUI

struct PomodoroRestVariantContentView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    let request: RestVariantRequest
    let appearance: OverlayPanelCollapsedAppearance

    var body: some View {
        switch appearance {
        case .wideNotchStrip:
            HStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image("PomodoroFocusStripIcon")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 14, height: 14)

                    Text(viewModel.presentation.phase == .focus
                         ? (viewModel.currentTaskTitle ?? "自由专注")
                         : "休息中")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .frame(width: 110, height: 14, alignment: .leading)

                Spacer(minLength: 0)

                Text(viewModel.presentation.timeText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(width: PomodoroRestVariantPresentation.collapsedWidth, height: PomodoroRestVariantPresentation.collapsedHeight)
        case .headerlessMiniPanel:
            VStack(spacing: PomodoroRestVariantPresentation.toastContentSpacing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: PomodoroRestVariantPresentation.toastIconSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(
                        width: PomodoroRestVariantPresentation.toastIconSize,
                        height: PomodoroRestVariantPresentation.toastIconSize
                    )

                Text(viewModel.presentation.phase == .focus && viewModel.currentTaskTitle != nil
                     ? "已完成一轮「\(viewModel.currentTaskTitle!)」"
                     : PomodoroRestVariantPresentation.toastMessage(for: viewModel.presentation.phase))
                    .font(.system(size: PomodoroRestVariantPresentation.toastTextFontSize, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }
            .frame(
                width: PomodoroRestVariantPresentation.toastContentWidth,
                height: PomodoroRestVariantPresentation.toastContentHeight,
                alignment: .top
            )
            .padding(.top, PomodoroRestVariantPresentation.toastContentTop)
            .frame(
                width: PomodoroRestVariantPresentation.toastWidth,
                height: PomodoroRestVariantPresentation.toastHeight,
                alignment: .top
            )
        case .transparent:
            EmptyView()
        }
    }
}
