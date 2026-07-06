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
        // ponytail: ASC 截图演示种子；仅 -seedDemo 时注入，生产零影响。
        if CommandLine.arguments.contains("-seedDemo"), timers.isEmpty {
            seedDemo(now: .now)
        }
    }

    private func seedDemo(now: Date) {
        // (label, emoji, total, remaining):混合将完成 / 进行中状态,让 burnerGrid 好看。
        let spec: [(String, String, TimeInterval, TimeInterval)] = [
            ("Pasta", "🍝", 480, 95),
            ("Rice",  "🍚", 300, 210),
            ("Tea",   "🍵", 180, 40),
            ("Eggs",  "🥚", 600, 520),
        ]
        for (label, emoji, total, remaining) in spec {
            timers.append(KitchenTimer(id: UUID(), label: label, emoji: emoji,
                                       totalDuration: total,
                                       endDate: now.addingTimeInterval(remaining)))
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

    func restart(_ id: UUID, now: Date = .now) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        var timer = timers[index]
        timer.endDate = now.addingTimeInterval(timer.totalDuration)
        timer.pausedRemaining = nil
        cancelNotification(id)
        schedule(timer)
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
        content.title = "\(timer.emoji) \(timer.localizedName)"
        content.body = String(localized: "Time's up!")
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

/// User-saved custom presets (Pro). Shown in the preset bar next to the builtins.
@MainActor
@Observable
final class PresetStore {
    private static let storageKey = "savedPresets"
    private let defaults: UserDefaults

    private(set) var saved: [Preset] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let list = try? JSONDecoder().decode([Preset].self, from: data) {
            saved = list
        }
    }

    func add(emoji: String, label: String, seconds: TimeInterval) {
        saved.append(Preset(id: UUID().uuidString, emoji: emoji, label: label, seconds: seconds))
        persist()
    }

    func remove(_ id: String) {
        saved.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
