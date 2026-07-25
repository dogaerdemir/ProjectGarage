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
            var predicates: [NSPredicate] = []
            if !includeArchived {
                predicates.append(NSPredicate(format: "isArchived == NO"))
            }
            let deletedVehicleIDs = try CoreDataDeletionMarkerStore.targetIDs(
                for: .vehicle,
                in: context
            )
            if !deletedVehicleIDs.isEmpty {
                predicates.append(
                    NSPredicate(
                        format: "NOT (id IN %@)",
                        Array(deletedVehicleIDs)
                    )
                )
            }
            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(
                    andPredicateWithSubpredicates: predicates
                )
            }
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).compactMap {
                try? CoreDataMapper.vehicle(from: $0)
            }
        }
    }

    func vehicle(id: UUID) async throws -> Vehicle? {
        try await persistence.read { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: id,
                in: context
            ) else {
                return nil
            }
            let request = NSFetchRequest<VehicleEntity>(entityName: "VehicleEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try context.fetch(request).first.flatMap {
                try? CoreDataMapper.vehicle(from: $0)
            }
        }
    }

    func save(_ vehicle: Vehicle, expectedUpdatedAt: Date?) async throws {
        try await persistence.write(
            rejectingConflictsWithMessage: expectedUpdatedAt == nil
                ? nil
                : "Bu araç başka bir cihazda değiştirildi. Güncel veriyi açıp değişikliklerinizi yeniden uygulayın."
        ) { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: vehicle.id,
                in: context
            ) else {
                throw GarageError.validation(
                    "Bu araç başka bir cihazda silindi. Araç listesini yenileyip işlemi yeniden deneyin."
                )
            }
            let request = NSFetchRequest<VehicleEntity>(entityName: "VehicleEntity")
            request.predicate = NSPredicate(format: "id == %@", vehicle.id as CVarArg)
            request.fetchLimit = 1
            let existingEntity = try context.fetch(request).first
            if let expectedUpdatedAt {
                guard let entity = existingEntity else { throw GarageError.notFound }
                guard entity.updatedAt == expectedUpdatedAt else {
                    throw GarageError.validation(
                        "Bu araç başka bir cihazda değiştirildi. Güncel veriyi açıp değişikliklerinizi yeniden uygulayın."
                    )
                }
            }
            let entity = existingEntity ?? VehicleEntity(context: context)
            CoreDataMapper.apply(vehicle, to: entity)
        }
    }

    func delete(id: UUID, expectedUpdatedAt: Date?) async throws {
        try await persistence.write(
            rejectingConflictsWithMessage: expectedUpdatedAt == nil
                ? nil
                : "Bu araç başka bir cihazda değiştirildi. Güncel veriyi açıp silme işlemini yeniden deneyin."
        ) { context in
            if try CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: id,
                in: context
            ) {
                return
            }
            if let expectedUpdatedAt {
                let vehicleRequest = NSFetchRequest<VehicleEntity>(
                    entityName: "VehicleEntity"
                )
                vehicleRequest.predicate = NSPredicate(
                    format: "id == %@",
                    id as CVarArg
                )
                vehicleRequest.fetchLimit = 1
                guard let vehicle = try context.fetch(vehicleRequest).first else {
                    throw GarageError.notFound
                }
                guard vehicle.updatedAt == expectedUpdatedAt else {
                    throw GarageError.validation(
                        "Bu araç başka bir cihazda değiştirildi. Güncel veriyi açıp silme işlemini yeniden deneyin."
                    )
                }
            }

            let recordRequest = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            recordRequest.predicate = NSPredicate(format: "vehicleID == %@", id as CVarArg)
            let recordIDs = try context.fetch(recordRequest).compactMap(\.id)
            try CoreDataDeletionMarkerStore.insertIfNeeded(
                .vehicle,
                targetID: id,
                in: context
            )
            for recordID in recordIDs {
                try CoreDataDeletionMarkerStore.insertIfNeeded(
                    .record,
                    targetID: recordID,
                    in: context
                )
            }

            if !recordIDs.isEmpty {
                let itemRequest = NSFetchRequest<RecordLineItemEntity>(entityName: "RecordLineItemEntity")
                itemRequest.predicate = NSPredicate(format: "recordID IN %@", recordIDs)
                try context.fetch(itemRequest).forEach(context.delete)
            }

            for name in ["VehicleEntity", "RecordEntity", "ReminderEntity", "DocumentEntity", "AssetEntity"] {
                let request = NSFetchRequest<NSManagedObject>(entityName: name)
                request.predicate = name == "VehicleEntity"
                    ? NSPredicate(format: "id == %@", id as CVarArg)
                    : NSPredicate(format: "vehicleID == %@", id as CVarArg)
                try context.fetch(request).forEach(context.delete)
            }
        }
    }
}
