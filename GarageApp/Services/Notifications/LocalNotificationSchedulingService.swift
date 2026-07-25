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
        let identifier = reminder.notificationIdentifier
            ?? "garage.reminder.\(reminder.id.uuidString)"
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = "Project Garage hatırlatmanızın zamanı geldi."
        content.sound = .default
        content.userInfo = ["garageReminderID": reminder.id.uuidString]
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

    func reconcile(reminders: [Reminder]) async {
        let activeReminders = reminders.filter {
            $0.isEnabled
                && $0.status != .completed
                && $0.status != .cancelled
                && ($0.dueDate.map { $0 > .now } ?? false)
        }
        let expectedIdentifiers = Set(activeReminders.map {
            $0.notificationIdentifier
                ?? "garage.reminder.\($0.id.uuidString)"
        })
        let pendingRequests = await center.pendingNotificationRequests()
        let staleIdentifiers = pendingRequests.compactMap { request -> String? in
            let isGarageReminder = request.content.userInfo["garageReminderID"] != nil
                || request.identifier.hasPrefix("garage.reminder.")
                || UUID(uuidString: request.identifier) != nil
            return isGarageReminder && !expectedIdentifiers.contains(request.identifier)
                ? request.identifier
                : nil
        }
        if !staleIdentifiers.isEmpty {
            center.removePendingNotificationRequests(
                withIdentifiers: staleIdentifiers
            )
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else {
            return
        }

        for reminder in activeReminders {
            var localReminder = reminder
            localReminder.notificationIdentifier = reminder.notificationIdentifier
                ?? "garage.reminder.\(reminder.id.uuidString)"
            _ = try? await schedule(reminder: localReminder)
        }
    }
}
