import SwiftUI

private func phaseColor(_ kind: PhaseType?) -> Color {
    switch kind {
    case .work: return Color(red: 0.91, green: 0.27, blue: 0.17)
    case .rest: return Color(red: 0.09, green: 0.63, blue: 0.54)
    case .prep: return Color(red: 0.85, green: 0.60, blue: 0.08)
    case nil:   return Color(red: 0.36, green: 0.42, blue: 1.00)
    }
}

struct WatchContentView: View {
    @EnvironmentObject var model: WatchTimerModel

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: model.fraction)
                    .stroke(phaseColor(model.kind), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(model.phaseLabel)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(phaseColor(model.kind))
                    Text(formatTime(model.displaySeconds))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    Text(model.state == .idle ? model.summary : model.roundText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 10)
            }
            .padding(4)

            HStack(spacing: 8) {
                if model.isActive {
                    Button { model.skip(-1) } label: { Image(systemName: "backward.fill") }
                }
                Button { model.toggle() } label: {
                    Image(systemName: model.state == .running ? "pause.fill" : "play.fill")
                }
                .tint(model.state == .running ? .orange : .green)
                if model.isActive {
                    Button { model.skip(1) } label: { Image(systemName: "forward.fill") }
                }
                if model.isActive || model.state == .done {
                    Button { model.reset() } label: { Image(systemName: "xmark") }
                        .tint(.red)
                }
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .font(.system(size: 15, weight: .semibold))

            if model.state == .idle && !model.hasSynced {
                Text("Open the iPhone app to sync settings")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 4)
    }
}
