//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CoreData
import Foundation

enum AssetStorageLimits {
    static let maximumDataSize = 20 * 1_024 * 1_024

    static func validate(data: Data) throws {
        guard data.count <= maximumDataSize else {
            throw GarageError.validation(
                "Fotoğraf veya belge 20 MB sınırını aşıyor. Dosyayı küçültüp yeniden deneyin."
            )
        }
    }
}

struct StoredAsset: Equatable, Sendable {
    let id: UUID
    let vehicleID: UUID?
    let recordID: UUID?
    let relativePath: String
    let data: Data?
    let mimeType: String?
    let createdAt: Date
    let updatedAt: Date
}

protocol AssetRepository: Sendable {
    @discardableResult
    func upsert(
        data: Data,
        vehicleID: UUID?,
        recordID: UUID?,
        relativePath: String,
        mimeType: String?
    ) async throws -> UUID

    func asset(relativePath: String) async throws -> StoredAsset?
    func data(relativePath: String) async throws -> Data?
    func containsData(relativePath: String) async throws -> Bool
    func delete(relativePath: String) async throws
}

extension AssetRepository {
    @discardableResult
    func upsert(
        data: Data,
        vehicleID: UUID?,
        relativePath: String,
        mimeType: String?
    ) async throws -> UUID {
        try await upsert(
            data: data,
            vehicleID: vehicleID,
            recordID: nil,
            relativePath: relativePath,
            mimeType: mimeType
        )
    }
}

actor CoreDataAssetRepository: AssetRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    @discardableResult
    func upsert(
        data: Data,
        vehicleID: UUID?,
        recordID: UUID?,
        relativePath: String,
        mimeType: String?
    ) async throws -> UUID {
        try Self.validate(relativePath: relativePath)
        try AssetStorageLimits.validate(data: data)

        return try await persistence.write { context in
            if let vehicleID,
               try CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: vehicleID,
                in: context
               ) {
                throw GarageError.validation(
                    "Bu dosyanın aracı başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                )
            }
            if let recordID,
               try CoreDataDeletionMarkerStore.contains(
                .record,
                targetID: recordID,
                in: context
               ) {
                throw GarageError.validation(
                    "Bu dosyanın kaydı başka bir cihazda silindi. Güncel veriyi açıp işlemi yeniden deneyin."
                )
            }
            let matches = try Self.fetchEntities(relativePath: relativePath, context: context)
            let retainedEntity = Self.newestEntity(in: matches)
            let entity = retainedEntity ?? AssetEntity(context: context)
            let now = Date.now

            if entity.id == nil {
                entity.id = UUID()
            }
            if entity.createdAt == nil {
                entity.createdAt = now
            }

            entity.vehicleID = vehicleID
            entity.recordID = recordID
            entity.relativePath = relativePath
            entity.data = data
            if let mimeType {
                entity.mimeType = mimeType
            }
            entity.updatedAt = now

            for duplicate in matches where duplicate !== entity {
                context.delete(duplicate)
            }

            guard let id = entity.id else {
                throw GarageError.persistence
            }
            return id
        }
    }

    func asset(relativePath: String) async throws -> StoredAsset? {
        try Self.validate(relativePath: relativePath)

        return try await persistence.backgroundRead { context in
            let matches = try Self.fetchEntities(relativePath: relativePath, context: context)
            guard let entity = Self.newestEntity(in: matches),
                  let id = entity.id
            else {
                return nil
            }
            if let vehicleID = entity.vehicleID,
               try CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: vehicleID,
                in: context
               ) {
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

            return StoredAsset(
                id: id,
                vehicleID: entity.vehicleID,
                recordID: entity.recordID,
                relativePath: entity.relativePath,
                data: entity.data,
                mimeType: entity.mimeType,
                createdAt: entity.createdAt ?? .distantPast,
                updatedAt: entity.updatedAt ?? entity.createdAt ?? .distantPast
            )
        }
    }

    func data(relativePath: String) async throws -> Data? {
        try await asset(relativePath: relativePath)?.data
    }

    func containsData(relativePath: String) async throws -> Bool {
        try Self.validate(relativePath: relativePath)
        return try await persistence.backgroundRead { context in
            let deletedVehicleIDs = try CoreDataDeletionMarkerStore.targetIDs(
                for: .vehicle,
                in: context
            )
            let deletedRecordIDs = try CoreDataDeletionMarkerStore.targetIDs(
                for: .record,
                in: context
            )
            var predicates = [
                NSPredicate(format: "relativePath == %@", relativePath),
                NSPredicate(format: "data != nil")
            ]
            if !deletedVehicleIDs.isEmpty {
                predicates.append(
                    NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "vehicleID == nil"),
                        NSPredicate(
                            format: "NOT (vehicleID IN %@)",
                            Array(deletedVehicleIDs)
                        )
                    ])
                )
            }
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
            let request = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
            request.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: predicates
            )
            request.fetchLimit = 1
            return try context.count(for: request) > 0
        }
    }

    func delete(relativePath: String) async throws {
        try Self.validate(relativePath: relativePath)

        try await persistence.write { context in
            let matches = try Self.fetchEntities(relativePath: relativePath, context: context)
            matches.forEach(context.delete)
        }
    }

    private static func validate(relativePath: String) throws {
        guard !relativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GarageError.fileOperation
        }
    }

    private static func fetchEntities(
        relativePath: String,
        context: NSManagedObjectContext
    ) throws -> [AssetEntity] {
        let request = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
        request.predicate = NSPredicate(format: "relativePath == %@", relativePath)
        return try context.fetch(request)
    }

    private static func newestEntity(in entities: [AssetEntity]) -> AssetEntity? {
        entities.max { lhs, rhs in
            let lhsDate = lhs.updatedAt ?? lhs.createdAt ?? .distantPast
            let rhsDate = rhs.updatedAt ?? rhs.createdAt ?? .distantPast

            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }

            let lhsID = lhs.id?.uuidString ?? ""
            let rhsID = rhs.id?.uuidString ?? ""
            return lhsID < rhsID
        }
    }
}
