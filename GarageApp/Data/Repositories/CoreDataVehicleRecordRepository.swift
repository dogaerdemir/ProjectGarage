//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class CoreDataVehicleRecordRepository: VehicleRecordRepository, @unchecked Sendable {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) { self.persistence = persistence }

    func fetchRecords(vehicleID: UUID, types: Set<RecordType>? = nil) async throws -> [VehicleRecord] {
        try await persistence.read { context in
            let request = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            var predicates = [NSPredicate(format: "vehicleID == %@", vehicleID as CVarArg)]
            if let types, !types.isEmpty {
                predicates.append(NSPredicate(format: "recordType IN %@", types.map(\.rawValue)))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "eventDate", ascending: false)]
            return try context.fetch(request).map(CoreDataMapper.record)
        }
    }

    func record(id: UUID) async throws -> VehicleRecord? {
        try await persistence.read { context in
            let request = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try context.fetch(request).first.map(CoreDataMapper.record)
        }
    }

    func save(_ record: VehicleRecord, lineItems: [RecordLineItem]) async throws {
        try await persistence.write { context in
            let request = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? RecordEntity(context: context)
            CoreDataMapper.apply(record, to: entity)

            let itemRequest = NSFetchRequest<RecordLineItemEntity>(entityName: "RecordLineItemEntity")
            itemRequest.predicate = NSPredicate(format: "recordID == %@", record.id as CVarArg)
            try context.fetch(itemRequest).forEach(context.delete)
            lineItems.forEach { item in
                CoreDataMapper.apply(item, to: RecordLineItemEntity(context: context))
            }
        }
    }

    func lineItems(recordID: UUID) async throws -> [RecordLineItem] {
        try await persistence.read { context in
            let request = NSFetchRequest<RecordLineItemEntity>(entityName: "RecordLineItemEntity")
            request.predicate = NSPredicate(format: "recordID == %@", recordID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            return try context.fetch(request).map(CoreDataMapper.lineItem)
        }
    }

    func delete(id: UUID) async throws {
        try await persistence.write { context in
            let recordRequest = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            recordRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            try context.fetch(recordRequest).forEach(context.delete)

            let itemRequest = NSFetchRequest<RecordLineItemEntity>(entityName: "RecordLineItemEntity")
            itemRequest.predicate = NSPredicate(format: "recordID == %@", id as CVarArg)
            try context.fetch(itemRequest).forEach(context.delete)
        }
    }
}
