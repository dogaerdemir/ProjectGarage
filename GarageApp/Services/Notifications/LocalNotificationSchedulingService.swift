//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation
import UserNotifications

final class LocalNotificationSchedulingService: NotificationSchedulingService, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        @unknown default: return false
        }
    }

    func schedule(reminder: Reminder) async throws -> String? {
        guard let dueDate = reminder.dueDate, dueDate > .now else { return nil }
        let identifier = reminder.notificationIdentifier ?? UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = "Project Garage hatırlatmanızın zamanı geldi."
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await center.add(request)
        return identifier
    }

    func cancel(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
