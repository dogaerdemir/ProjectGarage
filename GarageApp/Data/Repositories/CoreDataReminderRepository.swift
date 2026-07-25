//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class CoreDataReminderRepository: ReminderRepository, @unchecked Sendable {
    private let persistence: PersistenceController
    init(persistence: PersistenceController) { self.persistence = persistence }

    func fetchReminders(vehicleID: UUID) async throws -> [Reminder] {
        try await persistence.read { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: vehicleID,
                in: context
            ) else {
                return []
            }
            let request = NSFetchRequest<ReminderEntity>(entityName: "ReminderEntity")
            var predicates = [
                NSPredicate(format: "vehicleID == %@", vehicleID as CVarArg)
            ]
            let deletedRecordIDs = try CoreDataDeletionMarkerStore.targetIDs(
                for: .record,
                in: context
            )
            let deletedReminderIDs = try CoreDataDeletionMarkerStore.targetIDs(
                for: .reminder,
                in: context
            )
            if !deletedRecordIDs.isEmpty {
                predicates.append(
                    NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "recordID == nil"),
                        NSPredicate(
                            format: "NOT (recordID IN %@)",
                            Array(deletedRecordIDs)
                        )
                    ])
                )
            }
            if !deletedReminderIDs.isEmpty {
                predicates.append(
                    NSPredicate(
                        format: "NOT (id IN %@)",
                        Array(deletedReminderIDs)
                    )
                )
            }
            request.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: predicates
            )
            request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
            return try context.fetch(request).compactMap {
                try? CoreDataMapper.reminder(from: $0)
            }
        }
    }

    func save(_ reminder: Reminder, expectedUpdatedAt: Date?) async throws {
        try await persistence.write(
            rejectingConflictsWithMessage: expectedUpdatedAt == nil
                ? nil
                : "Bu hatırlatma başka bir cihazda değiştirildi. Güncel veriyi açıp değişikliklerinizi yeniden uygulayın."
        ) { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .reminder,
                targetID: reminder.id,
                in: context
            ) else {
                throw GarageError.validation(
                    "Bu hatırlatma başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                )
            }
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: reminder.vehicleID,
                in: context
            ) else {
                throw GarageError.validation(
                    "Bu hatırlatmanın aracı başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                )
            }
            if let recordID = reminder.recordID {
                guard try !CoreDataDeletionMarkerStore.contains(
                    .record,
                    targetID: recordID,
                    in: context
                ) else {
                    throw GarageError.validation(
                        "Bu hatırlatmanın kaydı başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                    )
                }
            }
            let vehicleRequest = NSFetchRequest<VehicleEntity>(
                entityName: "VehicleEntity"
            )
            vehicleRequest.predicate = NSPredicate(
                format: "id == %@",
                reminder.vehicleID as CVarArg
            )
            vehicleRequest.fetchLimit = 1
            guard try context.count(for: vehicleRequest) > 0 else {
                throw GarageError.validation(
                    "Bu hatırlatmanın aracı artık mevcut değil. Araç listesini yenileyip işlemi yeniden deneyin."
                )
            }
            if let recordID = reminder.recordID {
                let recordRequest = NSFetchRequest<RecordEntity>(
                    entityName: "RecordEntity"
                )
                recordRequest.predicate = NSPredicate(
                    format: "id == %@",
                    recordID as CVarArg
                )
                recordRequest.fetchLimit = 1
                guard try context.count(for: recordRequest) > 0 else {
                    throw GarageError.validation(
                        "Bu hatırlatmanın kaydı artık mevcut değil. Güncel veriyi açıp işlemi yeniden deneyin."
                    )
                }
            }
            let request = NSFetchRequest<ReminderEntity>(entityName: "ReminderEntity")
            request.predicate = NSPredicate(format: "id == %@", reminder.id as CVarArg)
            request.fetchLimit = 1
            let existingEntity = try context.fetch(request).first
            if let expectedUpdatedAt {
                guard let entity = existingEntity else { throw GarageError.notFound }
                guard entity.updatedAt == expectedUpdatedAt else {
                    throw GarageError.validation(
                        "Bu hatırlatma başka bir cihazda değiştirildi. Güncel veriyi açıp değişikliklerinizi yeniden uygulayın."
                    )
                }
            }
            let entity = existingEntity ?? ReminderEntity(context: context)
            CoreDataMapper.apply(reminder, to: entity)
        }
    }

    func delete(id: UUID, expectedUpdatedAt: Date?) async throws {
        try await persistence.write(
            rejectingConflictsWithMessage: expectedUpdatedAt == nil
                ? nil
                : "Bu hatırlatma başka bir cihazda değiştirildi. Güncel veriyi açıp silme işlemini yeniden deneyin."
        ) { context in
            if try CoreDataDeletionMarkerStore.contains(
                .reminder,
                targetID: id,
                in: context
            ) {
                return
            }
            let request = NSFetchRequest<ReminderEntity>(entityName: "ReminderEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let reminders = try context.fetch(request)
            if let expectedUpdatedAt {
                guard let reminder = reminders.first else {
                    throw GarageError.notFound
                }
                guard reminder.updatedAt == expectedUpdatedAt else {
                    throw GarageError.validation(
                        "Bu hatırlatma başka bir cihazda değiştirildi. Güncel veriyi açıp silme işlemini yeniden deneyin."
                    )
                }
            }
            try CoreDataDeletionMarkerStore.insertIfNeeded(
                .reminder,
                targetID: id,
                in: context
            )
            reminders.forEach(context.delete)
        }
    }
}
