//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct CreateReminderUseCase: Sendable {
    let repository: ReminderRepository
    let notificationService: NotificationSchedulingService

    func execute(_ reminder: Reminder, expectedUpdatedAt: Date? = nil) async throws {
        guard reminder.dueDate != nil || reminder.dueMileage != nil else {
            throw GarageError.validation("Tarih veya kilometre hedefi girilmelidir.")
        }

        var reminder = reminder
        let previousNotificationIdentifier = reminder.notificationIdentifier
        let shouldScheduleNotification = reminder.isEnabled && reminder.dueDate != nil
        reminder.notificationIdentifier = shouldScheduleNotification
            ? previousNotificationIdentifier
                ?? "garage.reminder.\(reminder.id.uuidString)"
            : nil
        try await repository.save(
            reminder,
            expectedUpdatedAt: expectedUpdatedAt
        )

        if shouldScheduleNotification {
            let granted = (try? await notificationService
                .requestAuthorizationIfNeeded()) ?? false
            if granted {
                _ = try? await notificationService.schedule(reminder: reminder)
            }
        } else if let previousNotificationIdentifier {
            await notificationService.cancel(
                identifier: previousNotificationIdentifier
            )
        }
    }
}

struct CompleteReminderUseCase: Sendable {
    let repository: ReminderRepository
    let notificationService: NotificationSchedulingService

    func execute(_ reminder: Reminder) async throws {
        var completedReminder = reminder
        completedReminder.status = .completed
        completedReminder.completedAt = .now
        completedReminder.updatedAt = .now
        try await repository.save(
            completedReminder,
            expectedUpdatedAt: reminder.updatedAt
        )
        await notificationService.cancel(
            identifier: reminder.notificationIdentifier
                ?? "garage.reminder.\(reminder.id.uuidString)"
        )
    }
}

struct EvaluateReminderStatusesUseCase: Sendable {
    let repository: ReminderRepository
    private let approachingDays: TimeInterval = 7 * 24 * 60 * 60
    private let approachingMileage: Int64 = 500

    func execute(vehicle: Vehicle, now: Date = .now) async throws -> [Reminder] {
        var reminders = try await repository.fetchReminders(vehicleID: vehicle.id)
        for index in reminders.indices where reminders[index].status != .completed && reminders[index].status != .cancelled {
            let date = reminders[index].dueDate
            let mileage = reminders[index].dueMileage
            let isOverdue = (date.map { $0 < now } ?? false) || (mileage.map { $0 <= vehicle.currentMileage } ?? false)
            let isApproaching = (date.map { $0.timeIntervalSince(now) <= approachingDays } ?? false)
                || (mileage.map { $0 - vehicle.currentMileage <= approachingMileage } ?? false)
            let nextStatus: ReminderStatus = isOverdue
                ? .overdue
                : (isApproaching ? .approaching : .active)
            guard nextStatus != reminders[index].status else { continue }
            let expectedUpdatedAt = reminders[index].updatedAt
            reminders[index].status = nextStatus
            reminders[index].updatedAt = now
            try await repository.save(
                reminders[index],
                expectedUpdatedAt: expectedUpdatedAt
            )
        }
        return reminders
    }
}
