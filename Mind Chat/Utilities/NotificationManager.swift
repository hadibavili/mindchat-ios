import UserNotifications

@MainActor
final class NotificationManager {

    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private var hasRequested = false

    private init() {}

    func requestPermissionIfNeeded() async {
        guard !hasRequested else { return }
        hasRequested = true
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func notifyResponseReady(title: String, preview: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = String(preview.prefix(150))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // fire immediately
        )
        center.add(request)
    }

    func clearDelivered() {
        center.removeAllDeliveredNotifications()
    }
}
