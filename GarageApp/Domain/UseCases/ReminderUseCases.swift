//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct CreateReminderUseCase: Sendable {
    let repository: ReminderRepository
    let notificationService: NotificationSchedulingService

    func execute(_ reminder: Reminder) async throws {
        guard reminder.dueDate != nil || reminder.dueMileage != nil else {
            throw GarageError.validation("Tarih veya kilometre hedefi girilmelidir.")
        }

        var reminder = reminder
        if reminder.isEnabled, reminder.dueDate != nil {
            let granted = try await notificationService.requestAuthorizationIfNeeded()
            if granted {
                reminder.notificationIdentifier = try await notificationService.schedule(reminder: reminder)
            }
        }
        try await repository.save(reminder)
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
            reminders[index].status = isOverdue ? .overdue : (isApproaching ? .approaching : .active)
            reminders[index].updatedAt = now
            try await repository.save(reminders[index])
        }
        return reminders
    }
}
