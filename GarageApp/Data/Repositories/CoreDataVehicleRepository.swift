//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class CoreDataVehicleRepository: VehicleRepository, @unchecked Sendable {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) { self.persistence = persistence }

    func fetchVehicles(includeArchived: Bool = false) async throws -> [Vehicle] {
        try await persistence.read { context in
            let request = NSFetchRequest<VehicleEntity>(entityName: "VehicleEntity")
            if !includeArchived { request.predicate = NSPredicate(format: "isArchived == NO") }
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).map(CoreDataMapper.vehicle)
        }
    }

    func vehicle(id: UUID) async throws -> Vehicle? {
        try await persistence.read { context in
            let request = NSFetchRequest<VehicleEntity>(entityName: "VehicleEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try context.fetch(request).first.map(CoreDataMapper.vehicle)
        }
    }

    func save(_ vehicle: Vehicle) async throws {
        try await persistence.write { context in
            let request = NSFetchRequest<VehicleEntity>(entityName: "VehicleEntity")
            request.predicate = NSPredicate(format: "id == %@", vehicle.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? VehicleEntity(context: context)
            CoreDataMapper.apply(vehicle, to: entity)
        }
    }

    func delete(id: UUID) async throws {
        try await persistence.write { context in
            let recordRequest = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            recordRequest.predicate = NSPredicate(format: "vehicleID == %@", id as CVarArg)
            let recordIDs = try context.fetch(recordRequest).map(\.id)

            if !recordIDs.isEmpty {
                let itemRequest = NSFetchRequest<RecordLineItemEntity>(entityName: "RecordLineItemEntity")
                itemRequest.predicate = NSPredicate(format: "recordID IN %@", recordIDs)
                try context.fetch(itemRequest).forEach(context.delete)
            }

            for name in ["VehicleEntity", "RecordEntity", "ReminderEntity", "DocumentEntity"] {
                let request = NSFetchRequest<NSManagedObject>(entityName: name)
                request.predicate = name == "VehicleEntity"
                    ? NSPredicate(format: "id == %@", id as CVarArg)
                    : NSPredicate(format: "vehicleID == %@", id as CVarArg)
                try context.fetch(request).forEach(context.delete)
            }
        }
    }
}
