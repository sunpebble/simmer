import ActivityKit
import Foundation

/// One Live Activity groups every timer — the whole stovetop in the Dynamic Island.
@MainActor
enum LiveActivity {
    static func sync(_ timers: [KitchenTimer]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = SimmerAttributes.ContentState(timers: timers.map(TimerSnap.init))
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            if timers.isEmpty {
                for activity in Activity<SimmerAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            } else if let activity = Activity<SimmerAttributes>.activities.first {
                await activity.update(content)
            } else {
                _ = try? Activity.request(attributes: SimmerAttributes(), content: content)
            }
        }
    }
}
