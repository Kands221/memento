import Foundation
import UserNotifications

/// One gentle daily nudge (prototype Reminders). No follow-ups, no streak guilt.
enum ReminderScheduler {
    static let identifier = "memento.daily"

    /// Returns false when notification permission is denied.
    static func setEnabled(_ on: Bool, minutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard on else { return true }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Memento"
        content.body = "A few lines tonight? Even one sentence counts."
        content.sound = .default
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }

    /// "8:30 PM"
    static func label(minutes: Int) -> String {
        let hour = minutes / 60, minute = minutes % 60
        return "\(hour % 12 == 0 ? 12 : hour % 12):\(String(format: "%02d", minute)) \(hour < 12 ? "AM" : "PM")"
    }
}
