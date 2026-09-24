import ActivityKit
import SwiftUI
import WidgetKit

@main
struct T4BotLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        T4BotLiveActivityWidget()
    }
}

struct T4BotLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: T4BotActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: icon(for: context.state.status))
                    .foregroundStyle(tint(for: context.state.status))
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.title)
                        .font(.headline)
                    Text(context.state.message)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let pnl = context.state.pnl {
                    Text(pnl, format: .currency(code: "USD").sign(strategy: .always()))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }
            }
            .padding(.horizontal)
            .activityBackgroundTint(.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.symbol.isEmpty ? "T4" : context.state.symbol, systemImage: icon(for: context.state.status))
                        .foregroundStyle(tint(for: context.state.status))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let pnl = context.state.pnl {
                        Text(pnl, format: .number.precision(.fractionLength(2)).sign(strategy: .always()))
                            .monospacedDigit()
                            .foregroundStyle(pnl >= 0 ? .green : .red)
                    } else {
                        Text("LIVE")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.caption)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: icon(for: context.state.status))
                    .foregroundStyle(tint(for: context.state.status))
            } compactTrailing: {
                Text(context.state.symbol.isEmpty ? "T4" : context.state.symbol)
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: icon(for: context.state.status))
                    .foregroundStyle(tint(for: context.state.status))
            }
            .keylineTint(tint(for: context.state.status))
        }
    }

    private func icon(for status: String) -> String {
        switch status {
        case "profit": return "arrow.up.right.circle.fill"
        case "loss": return "arrow.down.right.circle.fill"
        case "idle": return "pause.circle.fill"
        default: return "waveform.path.ecg"
        }
    }

    private func tint(for status: String) -> Color {
        switch status {
        case "profit": return .green
        case "loss": return .red
        case "idle": return .secondary
        default: return .cyan
        }
    }
}
