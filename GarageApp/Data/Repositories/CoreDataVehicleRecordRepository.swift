//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class CoreDataVehicleRecordRepository: VehicleRecordRepository, @unchecked Sendable {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) { self.persistence = persistence }

    func fetchRecords(vehicleID: UUID, types: Set<RecordType>? = nil) async throws -> [VehicleRecord] {
        try await persistence.read { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: vehicleID,
                in: context
            ) else {
                return []
            }
            let request = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            var predicates = [NSPredicate(format: "vehicleID == %@", vehicleID as CVarArg)]
            if let types, !types.isEmpty {
                predicates.append(NSPredicate(format: "recordType IN %@", types.map(\.rawValue)))
            }
            let deletedRecordIDs = try CoreDataDeletionMarkerStore.targetIDs(
                for: .record,
                in: context
            )
            if !deletedRecordIDs.isEmpty {
                predicates.append(
                    NSPredicate(
                        format: "NOT (id IN %@)",
                        Array(deletedRecordIDs)
                    )
                )
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "eventDate", ascending: false)]
            return try context.fetch(request).compactMap {
                try? CoreDataMapper.record(from: $0)
            }
        }
    }

    func record(id: UUID) async throws -> VehicleRecord? {
        try await persistence.read { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .record,
                targetID: id,
                in: context
            ) else {
                return nil
            }
            let request = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let entity = try context.fetch(request).first,
                  let vehicleID = entity.vehicleID,
                  try !CoreDataDeletionMarkerStore.contains(
                    .vehicle,
                    targetID: vehicleID,
                    in: context
                  )
            else {
                return nil
            }
            return try? CoreDataMapper.record(from: entity)
        }
    }

    func save(
        _ record: VehicleRecord,
        lineItems: [RecordLineItem],
        expectedUpdatedAt: Date?,
        vehicleMileageUpdate: VehicleMileageUpdate?
    ) async throws {
        let rejectsConflicts = expectedUpdatedAt != nil
            || vehicleMileageUpdate != nil
        try await persistence.write(
            rejectingConflictsWithMessage: rejectsConflicts
                ? "Kayıt veya araç başka bir cihazda değiştirildi. Güncel veriyi açıp değişikliklerinizi yeniden uygulayın."
                : nil
        ) { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: record.vehicleID,
                in: context
            ) else {
                throw GarageError.validation(
                    "Bu kaydın aracı başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                )
            }
            guard try !CoreDataDeletionMarkerStore.contains(
                .record,
                targetID: record.id,
                in: context
            ) else {
                throw GarageError.validation(
                    "Bu kayıt başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                )
            }
            let request = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            request.fetchLimit = 1
            let existingEntity = try context.fetch(request).first
            if let expectedUpdatedAt {
                guard let entity = existingEntity else { throw GarageError.notFound }
                guard entity.updatedAt == expectedUpdatedAt else {
                    throw GarageError.validation(
                        "Bu kayıt başka bir cihazda değiştirildi. Güncel kaydı açıp değişikliklerinizi yeniden uygulayın."
                    )
                }
            }

            let itemRequest = NSFetchRequest<RecordLineItemEntity>(entityName: "RecordLineItemEntity")
            itemRequest.predicate = NSPredicate(format: "recordID == %@", record.id as CVarArg)
            let existingItems = try context.fetch(itemRequest)
            var existingByID: [UUID: RecordLineItemEntity] = [:]
            for existingItem in existingItems {
                guard let id = existingItem.id, existingByID[id] == nil else {
                    context.delete(existingItem)
                    continue
                }
                existingByID[id] = existingItem
            }

            let incomingIDs = Set(lineItems.map(\.id))
            guard incomingIDs.count == lineItems.count else {
                throw GarageError.persistence
            }

            let vehicleRequest = NSFetchRequest<VehicleEntity>(
                entityName: "VehicleEntity"
            )
            vehicleRequest.predicate = NSPredicate(
                format: "id == %@",
                record.vehicleID as CVarArg
            )
            vehicleRequest.fetchLimit = 1
            guard let vehicleEntity = try context.fetch(vehicleRequest).first else {
                throw GarageError.validation(
                    "Bu kaydın aracı artık mevcut değil. Araç listesini yenileyip işlemi yeniden deneyin."
                )
            }
            if let vehicleMileageUpdate {
                guard vehicleEntity.updatedAt == vehicleMileageUpdate.expectedUpdatedAt else {
                    throw GarageError.validation(
                        "Araç başka bir cihazda değiştirildi. Güncel veriyi açıp kayıt işlemini yeniden deneyin."
                    )
                }
            }

            let entity = existingEntity ?? RecordEntity(context: context)
            CoreDataMapper.apply(record, to: entity)
            lineItems.forEach { item in
                let itemEntity = existingByID[item.id] ?? RecordLineItemEntity(context: context)
                CoreDataMapper.apply(item, to: itemEntity)
            }
            for (id, existingItem) in existingByID where !incomingIDs.contains(id) {
                context.delete(existingItem)
            }
            if let vehicleMileageUpdate {
                vehicleEntity.currentMileage = vehicleMileageUpdate.mileage
                vehicleEntity.updatedAt = vehicleMileageUpdate.updatedAt
            }
        }
    }

    func lineItems(recordID: UUID) async throws -> [RecordLineItem] {
        try await persistence.read { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .record,
                targetID: recordID,
                in: context
            ) else {
                return []
            }
            let request = NSFetchRequest<RecordLineItemEntity>(entityName: "RecordLineItemEntity")
            request.predicate = NSPredicate(format: "recordID == %@", recordID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            return try context.fetch(request).compactMap {
                try? CoreDataMapper.lineItem(from: $0)
            }
        }
    }

    func delete(id: UUID, expectedUpdatedAt: Date?) async throws {
        try await persistence.write(
            rejectingConflictsWithMessage: expectedUpdatedAt == nil
                ? nil
                : "Bu kayıt başka bir cihazda değiştirildi. Güncel kaydı açıp silme işlemini yeniden deneyin."
        ) { context in
            if try CoreDataDeletionMarkerStore.contains(
                .record,
                targetID: id,
                in: context
            ) {
                return
            }
            let recordRequest = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            recordRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let records = try context.fetch(recordRequest)
            if let expectedUpdatedAt {
                guard let record = records.first else { throw GarageError.notFound }
                guard record.updatedAt == expectedUpdatedAt else {
                    throw GarageError.validation(
                        "Bu kayıt başka bir cihazda değiştirildi. Güncel kaydı açıp silme işlemini yeniden deneyin."
                    )
                }
            }
            try CoreDataDeletionMarkerStore.insertIfNeeded(
                .record,
                targetID: id,
                in: context
            )
            records.forEach(context.delete)

            let itemRequest = NSFetchRequest<RecordLineItemEntity>(entityName: "RecordLineItemEntity")
            itemRequest.predicate = NSPredicate(format: "recordID == %@", id as CVarArg)
            try context.fetch(itemRequest).forEach(context.delete)

            let reminderRequest = NSFetchRequest<ReminderEntity>(entityName: "ReminderEntity")
            reminderRequest.predicate = NSPredicate(format: "recordID == %@", id as CVarArg)
            try context.fetch(reminderRequest).forEach(context.delete)

            let documentRequest = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            documentRequest.predicate = NSPredicate(format: "recordID == %@", id as CVarArg)
            let documents = try context.fetch(documentRequest)
            let documentPaths = documents.map(\.localRelativePath)
            documents.forEach(context.delete)

            if !documentPaths.isEmpty {
                let assetRequest = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
                assetRequest.predicate = NSCompoundPredicate(
                    orPredicateWithSubpredicates: [
                        NSPredicate(format: "recordID == %@", id as CVarArg),
                        NSPredicate(
                            format: "relativePath IN %@",
                            documentPaths
                        )
                    ]
                )
                try context.fetch(assetRequest).forEach(context.delete)
            } else {
                let assetRequest = NSFetchRequest<AssetEntity>(
                    entityName: "AssetEntity"
                )
                assetRequest.predicate = NSPredicate(
                    format: "recordID == %@",
                    id as CVarArg
                )
                try context.fetch(assetRequest).forEach(context.delete)
            }
        }
    }
}
