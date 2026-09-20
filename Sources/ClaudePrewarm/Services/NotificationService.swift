import Foundation
import UserNotifications

/// Failures only — a daily success notification would just be noise.
enum NotificationService {
    private static var authorized = false

    static func requestAuthorizationIfNeeded() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            authorized = granted
        }
    }

    static func notifyFailure(_ message: String) {
        guard Bundle.main.bundleIdentifier != nil, authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Claude Prewarm failed"
        content.body = message
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
