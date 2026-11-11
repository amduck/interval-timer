import ActivityKit
import SwiftUI
import WidgetKit

private typealias LiveState = IntervalActivityAttributes.ContentState

private func phaseColor(_ kind: String) -> Color {
    switch kind {
    case "work": return Color(red: 0.91, green: 0.27, blue: 0.17)
    case "rest": return Color(red: 0.09, green: 0.63, blue: 0.54)
    case "prep": return Color(red: 0.85, green: 0.60, blue: 0.08)
    default:     return Color(red: 0.36, green: 0.42, blue: 1.00)
    }
}

private func phaseSymbol(_ kind: String) -> String {
    switch kind {
    case "work": return "flame.fill"
    case "rest": return "pause.circle.fill"
    case "prep": return "timer"
    default:     return "checkmark.circle.fill"
    }
}

/// Live countdown (system-drawn) or a frozen value while paused / finished.
private struct Countdown: View {
    let state: LiveState
    var body: some View {
        if state.isPaused {
            Text(clockString(state.pausedSeconds))
        } else {
            Text(timerInterval: state.phaseStart...state.phaseEnd, countsDown: true, showsHours: false)
        }
    }
}

private struct LockScreenView: View {
    let state: LiveState
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: phaseSymbol(state.kind))
                    Text(state.isPaused && state.kind != "done" ? "\(state.label) · PAUSED" : state.label)
                        .fontWeight(.bold)
                        .tracking(1.5)
                }
                .font(.footnote)
                .foregroundStyle(phaseColor(state.kind))

                Text(state.roundText)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text(state.nextText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Countdown(state: state)
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
    }
}

struct IntervalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IntervalActivityAttributes.self) { context in
            LockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.label)
                            .font(.headline)
                            .foregroundStyle(phaseColor(context.state.kind))
                        Text(context.state.roundText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: context.state)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.nextText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: phaseSymbol(context.state.kind))
                    .foregroundStyle(phaseColor(context.state.kind))
            } compactTrailing: {
                Countdown(state: context.state)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48)
            } minimal: {
                Image(systemName: phaseSymbol(context.state.kind))
                    .foregroundStyle(phaseColor(context.state.kind))
            }
            .keylineTint(phaseColor(context.state.kind))
        }
    }
}
