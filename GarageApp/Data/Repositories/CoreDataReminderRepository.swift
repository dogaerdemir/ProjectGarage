//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class CoreDataReminderRepository: ReminderRepository, @unchecked Sendable {
    private let persistence: PersistenceController
    init(persistence: PersistenceController) { self.persistence = persistence }

    func fetchReminders(vehicleID: UUID) async throws -> [Reminder] {
        try await persistence.read { context in
            let request = NSFetchRequest<ReminderEntity>(entityName: "ReminderEntity")
            request.predicate = NSPredicate(format: "vehicleID == %@", vehicleID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
            return try context.fetch(request).map(CoreDataMapper.reminder)
        }
    }

    func save(_ reminder: Reminder) async throws {
        try await persistence.write { context in
            let request = NSFetchRequest<ReminderEntity>(entityName: "ReminderEntity")
            request.predicate = NSPredicate(format: "id == %@", reminder.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? ReminderEntity(context: context)
            CoreDataMapper.apply(reminder, to: entity)
        }
    }

    func delete(id: UUID) async throws {
        try await persistence.write { context in
            let request = NSFetchRequest<ReminderEntity>(entityName: "ReminderEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            try context.fetch(request).forEach(context.delete)
        }
    }
}
