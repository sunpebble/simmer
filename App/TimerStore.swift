import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class TimerStore {
    private static let storageKey = "timers"
    private let defaults: UserDefaults
    private let live: Bool  // false in tests: no notifications / Live Activity

    private(set) var timers: [KitchenTimer] = []

    init(defaults: UserDefaults = .standard, live: Bool = true) {
        self.defaults = defaults
        self.live = live
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([KitchenTimer].self, from: data) {
            timers = saved
        }
    }

    func start(label: String, emoji: String, duration: TimeInterval, now: Date = .now) {
        let timer = KitchenTimer(id: UUID(), label: label, emoji: emoji,
                                 totalDuration: duration,
                                 endDate: now.addingTimeInterval(duration))
        timers.append(timer)
        if live {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
            }
        }
        schedule(timer)
        changed()
    }

    func togglePause(_ id: UUID, now: Date = .now) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        var timer = timers[index]
        if let end = timer.endDate {
            timer.pausedRemaining = max(0, end.timeIntervalSince(now))
            timer.endDate = nil
            cancelNotification(id)
        } else {
            timer.endDate = now.addingTimeInterval(timer.pausedRemaining ?? 0)
            timer.pausedRemaining = nil
            schedule(timer)
        }
        timers[index] = timer
        changed()
    }

    func addMinute(_ id: UUID, now: Date = .now) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        var timer = timers[index]
        if let end = timer.endDate {
            timer.endDate = max(end, now).addingTimeInterval(60)
            cancelNotification(id)
            schedule(timer)
        } else {
            timer.pausedRemaining = (timer.pausedRemaining ?? 0) + 60
        }
        timer.totalDuration += 60
        timers[index] = timer
        changed()
    }

    func dismiss(_ id: UUID) {
        cancelNotification(id)
        timers.removeAll { $0.id == id }
        changed()
    }

    private func changed() {
        if let data = try? JSONEncoder().encode(timers) {
            defaults.set(data, forKey: Self.storageKey)
        }
        guard live else { return }
        LiveActivity.sync(timers)
    }

    private func schedule(_ timer: KitchenTimer) {
        guard live, let end = timer.endDate else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(timer.emoji) \(timer.label)"
        content.body = "Time's up!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger))
    }

    private func cancelNotification(_ id: UUID) {
        guard live else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}
