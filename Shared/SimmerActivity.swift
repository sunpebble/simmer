import ActivityKit
import Foundation

struct SimmerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var timers: [TimerSnap]

        /// Running timer that fires next; paused timers sort last.
        var soonest: TimerSnap? {
            timers.min { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }
        }
    }
}

struct TimerSnap: Codable, Hashable, Identifiable {
    let id: UUID
    let label: String
    let emoji: String
    let endDate: Date?
    let pausedRemaining: TimeInterval?

    init(_ timer: KitchenTimer) {
        id = timer.id
        label = timer.label
        emoji = timer.emoji
        endDate = timer.endDate
        pausedRemaining = timer.pausedRemaining
    }
}
