import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SimmerWidgetBundle: WidgetBundle {
    var body: some Widget {
        SimmerLiveActivity()
    }
}

private let cream = Color(red: 1.0, green: 0.965, blue: 0.91)
private let ink = Color(red: 0.137, green: 0.153, blue: 0.20)
private let flame = Color(red: 0.969, green: 0.718, blue: 0.20)

struct SimmerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SimmerAttributes.self) { context in
            TimerListView(timers: context.state.timers, tint: ink, faded: ink.opacity(0.55))
                .padding(16)
                .activityBackgroundTint(cream)
                .activitySystemActionForegroundColor(ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    TimerListView(timers: context.state.timers,
                                  tint: .white, faded: .white.opacity(0.6))
                }
            } compactLeading: {
                Text(context.state.soonest?.emoji ?? "🍳")
            } compactTrailing: {
                CountdownText(snap: context.state.soonest)
                    .foregroundStyle(flame)
                    .frame(maxWidth: 52)
                    .monospacedDigit()
            } minimal: {
                Text(context.state.soonest?.emoji ?? "🍳")
            }
        }
    }
}

struct TimerListView: View {
    let timers: [TimerSnap]
    let tint: Color
    let faded: Color

    var body: some View {
        VStack(spacing: 8) {
            ForEach(timers.prefix(4)) { snap in
                HStack(spacing: 10) {
                    Text(snap.emoji).font(.system(size: 22))
                    Text(NSLocalizedString(snap.label, comment: ""))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Spacer()
                    CountdownText(snap: snap)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: 90, alignment: .trailing)
                }
            }
            if timers.count > 4 {
                Text("+\(timers.count - 4) more")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(faded)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .foregroundStyle(tint)
    }
}

struct CountdownText: View {
    let snap: TimerSnap?

    var body: some View {
        if let snap {
            if let end = snap.endDate {
                if end > .now {
                    // Self-updating countdown — no pushes needed
                    Text(timerInterval: .now...end, countsDown: true)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("DONE").foregroundStyle(flame)
                }
            } else {
                Text(pausedText(snap.pausedRemaining ?? 0)).opacity(0.6)
            }
        }
    }

    private func pausedText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
