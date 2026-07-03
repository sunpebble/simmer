import SwiftUI
import UserNotifications

@main
struct SimmerApp: App {
    @State private var pro = ProStore()
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(pro)
                .task {
                    await pro.load()
                    await pro.listenForTransactions()
                }
        }
    }
}

/// Shows the "time's up" banner + sound while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
