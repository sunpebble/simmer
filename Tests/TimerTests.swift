import XCTest
@testable import Simmer

@MainActor
final class TimerTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "SimmerTests")!
        defaults.removePersistentDomain(forName: "SimmerTests")
        return defaults
    }

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testRemainingProgressAndDone() {
        let store = TimerStore(defaults: freshDefaults(), live: false)
        store.start(label: "Egg", emoji: "🥚", duration: 360, now: t0)
        let timer = store.timers[0]
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(60)), 300, accuracy: 0.001)
        XCTAssertEqual(timer.progress(at: t0.addingTimeInterval(180)), 0.5, accuracy: 0.001)
        XCTAssertFalse(timer.isDone(at: t0.addingTimeInterval(359)))
        XCTAssertTrue(timer.isDone(at: t0.addingTimeInterval(361)))
    }

    func testPauseResumeKeepsRemaining() {
        let store = TimerStore(defaults: freshDefaults(), live: false)
        store.start(label: "Pasta", emoji: "🍝", duration: 600, now: t0)
        let id = store.timers[0].id

        store.togglePause(id, now: t0.addingTimeInterval(100))
        XCTAssertFalse(store.timers[0].isRunning)
        XCTAssertEqual(store.timers[0].pausedRemaining!, 500, accuracy: 0.001)

        // Resume much later: remaining picks up where it left off
        store.togglePause(id, now: t0.addingTimeInterval(10_000))
        XCTAssertTrue(store.timers[0].isRunning)
        XCTAssertEqual(store.timers[0].remaining(at: t0.addingTimeInterval(10_000)), 500, accuracy: 0.001)
    }

    func testAddMinute() {
        let store = TimerStore(defaults: freshDefaults(), live: false)
        store.start(label: "Rice", emoji: "🍚", duration: 900, now: t0)
        let id = store.timers[0].id
        store.addMinute(id, now: t0)
        XCTAssertEqual(store.timers[0].remaining(at: t0), 960, accuracy: 0.001)
        XCTAssertEqual(store.timers[0].totalDuration, 960, accuracy: 0.001)
    }

    func testPersistenceRoundtrip() {
        let defaults = freshDefaults()
        let store = TimerStore(defaults: defaults, live: false)
        store.start(label: "Tea", emoji: "🍵", duration: 180, now: t0)
        store.start(label: "Oven", emoji: "🍞", duration: 1500, now: t0)

        let reloaded = TimerStore(defaults: defaults, live: false)
        XCTAssertEqual(reloaded.timers, store.timers)
    }

    func testDismissRemoves() {
        let store = TimerStore(defaults: freshDefaults(), live: false)
        store.start(label: "Tea", emoji: "🍵", duration: 180, now: t0)
        store.dismiss(store.timers[0].id)
        XCTAssertTrue(store.timers.isEmpty)
    }

    func testSoonestPrefersRunningTimer() {
        let running = KitchenTimer(id: UUID(), label: "A", emoji: "🍵", totalDuration: 60,
                                   endDate: t0.addingTimeInterval(60), pausedRemaining: nil)
        let paused = KitchenTimer(id: UUID(), label: "B", emoji: "🍝", totalDuration: 30,
                                  endDate: nil, pausedRemaining: 10)
        let state = SimmerAttributes.ContentState(timers: [paused, running].map(TimerSnap.init))
        XCTAssertEqual(state.soonest?.label, "A")
    }
}
