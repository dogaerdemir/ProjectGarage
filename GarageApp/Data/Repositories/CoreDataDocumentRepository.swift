//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class CoreDataDocumentRepository: DocumentRepository, @unchecked Sendable {
    private let persistence: PersistenceController
    init(persistence: PersistenceController) { self.persistence = persistence }

    func fetchDocuments(vehicleID: UUID) async throws -> [GarageDocument] {
        try await persistence.read { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: vehicleID,
                in: context
            ) else {
                return []
            }
            let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            var predicates = [
                NSPredicate(format: "vehicleID == %@", vehicleID as CVarArg)
            ]
            let deletedRecordIDs = try CoreDataDeletionMarkerStore.targetIDs(
                for: .record,
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
            request.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: predicates
            )
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try context.fetch(request).compactMap {
                try? CoreDataMapper.document(from: $0)
            }
        }
    }

    func document(id: UUID) async throws -> GarageDocument? {
        try await persistence.read { context in
            let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
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
            if let recordID = entity.recordID,
               try CoreDataDeletionMarkerStore.contains(
                .record,
                targetID: recordID,
                in: context
               ) {
                return nil
            }
            return try? CoreDataMapper.document(from: entity)
        }
    }

    func save(_ document: GarageDocument) async throws {
        try await persistence.write { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: document.vehicleID,
                in: context
            ) else {
                throw GarageError.validation(
                    "Bu belgenin aracı başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                )
            }
            if let recordID = document.recordID {
                guard try !CoreDataDeletionMarkerStore.contains(
                    .record,
                    targetID: recordID,
                    in: context
                ) else {
                    throw GarageError.validation(
                        "Bu belgenin kaydı başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                    )
                }
            }
            let vehicleRequest = NSFetchRequest<VehicleEntity>(
                entityName: "VehicleEntity"
            )
            vehicleRequest.predicate = NSPredicate(
                format: "id == %@",
                document.vehicleID as CVarArg
            )
            vehicleRequest.fetchLimit = 1
            guard try context.count(for: vehicleRequest) > 0 else {
                throw GarageError.validation(
                    "Bu belgenin aracı artık mevcut değil. Araç listesini yenileyip işlemi yeniden deneyin."
                )
            }
            if let recordID = document.recordID {
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
                        "Bu belgenin kaydı artık mevcut değil. Güncel veriyi açıp işlemi yeniden deneyin."
                    )
                }
            }
            let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            request.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? DocumentEntity(context: context)
            CoreDataMapper.apply(document, to: entity)
        }
    }

    func delete(id: UUID) async throws {
        try await persistence.write { context in
            let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let documents = try context.fetch(request)
            let paths = documents.map(\.localRelativePath)
            documents.forEach(context.delete)
            guard !paths.isEmpty else { return }

            let assetRequest = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
            assetRequest.predicate = NSPredicate(format: "relativePath IN %@", paths)
            try context.fetch(assetRequest).forEach(context.delete)
        }
    }
}
