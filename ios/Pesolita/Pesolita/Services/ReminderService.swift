import Foundation
import UserNotifications

actor ReminderService {
    static let shared = ReminderService()
    private let dailyID = "pesolita.daily-log"

    func setDailyReminder(enabled: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [dailyID])
            return true
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }
            let content = UNMutableNotificationContent()
            content.title = "A quick peso check"
            content.body = "Anything to log today? Two taps keeps your wallet honest."
            content.sound = .default
            var time = DateComponents()
            time.hour = 21
            let request = UNNotificationRequest(
                identifier: dailyID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            )
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
