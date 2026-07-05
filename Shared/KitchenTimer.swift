import Foundation

struct KitchenTimer: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var emoji: String
    var totalDuration: TimeInterval
    var endDate: Date?                  // set while running
    var pausedRemaining: TimeInterval?  // set while paused

    var isRunning: Bool { endDate != nil }

    func remaining(at now: Date = .now) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(now)) }
        return pausedRemaining ?? 0
    }

    func isDone(at now: Date = .now) -> Bool {
        isRunning && remaining(at: now) <= 0
    }

    func overdue(at now: Date = .now) -> TimeInterval {
        guard let endDate, now > endDate else { return 0 }
        return now.timeIntervalSince(endDate)
    }

    func progress(at now: Date = .now) -> Double {
        guard totalDuration > 0 else { return 1 }
        return min(1, 1 - remaining(at: now) / totalDuration)
    }
}

struct Preset: Identifiable, Equatable, Codable {
    let id: String
    let emoji: String
    let label: String
    let seconds: TimeInterval

    static let builtins: [Preset] = [
        Preset(id: "tea", emoji: "🍵", label: "Tea", seconds: 3 * 60),
        Preset(id: "ramen", emoji: "🍜", label: "Ramen", seconds: 4 * 60),
        Preset(id: "french-press", emoji: "☕", label: "French Press", seconds: 4 * 60),
        Preset(id: "steak", emoji: "🥩", label: "Rest Steak", seconds: 5 * 60),
        Preset(id: "soft-egg", emoji: "🥚", label: "Soft Egg", seconds: 6 * 60),
        Preset(id: "veg", emoji: "🥦", label: "Steam Veg", seconds: 8 * 60),
        Preset(id: "hard-egg", emoji: "🍳", label: "Hard Egg", seconds: 10 * 60),
        Preset(id: "pasta", emoji: "🍝", label: "Pasta", seconds: 10 * 60),
        Preset(id: "dumplings", emoji: "🥟", label: "Dumplings", seconds: 10 * 60),
        Preset(id: "rice", emoji: "🍚", label: "Rice", seconds: 15 * 60),
        Preset(id: "potatoes", emoji: "🥔", label: "Potatoes", seconds: 20 * 60),
        Preset(id: "oven", emoji: "🍞", label: "Oven", seconds: 25 * 60),
    ]
}

func timerText(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    if total >= 3600 {
        return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
    return String(format: "%d:%02d", total / 60, total % 60)
}
