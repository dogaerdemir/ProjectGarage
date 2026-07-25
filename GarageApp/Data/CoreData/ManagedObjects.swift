//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

@objc(VehicleEntity)
final class VehicleEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var nickname: String
    @NSManaged var make: String
    @NSManaged var model: String
    @NSManaged var modelYear: Int64
    @NSManaged var fuelType: String?
    @NSManaged var transmissionType: String?
    @NSManaged var plateNumber: String?
    @NSManaged var vin: String?
    @NSManaged var currentMileage: Int64
    @NSManaged var photoIdentifier: String?
    @NSManaged var catalogMakeID: String?
    @NSManaged var catalogModelID: String?
    @NSManaged var isArchived: Bool
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}

@objc(RecordEntity)
final class RecordEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var vehicleID: UUID?
    @NSManaged var recordType: String
    @NSManaged var title: String
    @NSManaged var eventDate: Date?
    @NSManaged var odometer: Int64
    @NSManaged var hasOdometer: Bool
    @NSManaged var totalAmount: NSDecimalNumber?
    @NSManaged var currencyCode: String
    @NSManaged var vendorName: String?
    @NSManaged var notes: String?
    @NSManaged var source: String
    @NSManaged var liters: NSDecimalNumber?
    @NSManaged var unitPrice: NSDecimalNumber?
    @NSManaged var isFullTank: Bool
    @NSManaged var hasFullTankValue: Bool
    @NSManaged var policyType: String?
    @NSManaged var policyNumber: String?
    @NSManaged var startDate: Date?
    @NSManaged var endDate: Date?
    @NSManaged var inspectionType: String?
    @NSManaged var validityDate: Date?
    @NSManaged var outcome: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}

@objc(RecordLineItemEntity)
final class RecordLineItemEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var recordID: UUID?
    @NSManaged var name: String
    @NSManaged var category: String?
    @NSManaged var brand: String?
    @NSManaged var partNumber: String?
    @NSManaged var amount: NSDecimalNumber?
    @NSManaged var warrantyEndDate: Date?
    @NSManaged var notes: String?
    @NSManaged var sortOrder: Int64
}

@objc(ReminderEntity)
final class ReminderEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var vehicleID: UUID?
    @NSManaged var recordID: UUID?
    @NSManaged var title: String
    @NSManaged var dueDate: Date?
    @NSManaged var dueMileage: Int64
    @NSManaged var hasDueMileage: Bool
    @NSManaged var status: String
    @NSManaged var isEnabled: Bool
    @NSManaged var notificationIdentifier: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var completedAt: Date?
}

@objc(DocumentEntity)
final class DocumentEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var vehicleID: UUID?
    @NSManaged var recordID: UUID?
    @NSManaged var documentType: String
    @NSManaged var displayName: String
    @NSManaged var mimeType: String
    @NSManaged var fileSize: Int64
    @NSManaged var localRelativePath: String
    @NSManaged var thumbnailRelativePath: String?
    @NSManaged var checksum: String?
    @NSManaged var createdAt: Date?
}

@objc(AssetEntity)
final class AssetEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var vehicleID: UUID?
    @NSManaged var recordID: UUID?
    @NSManaged var relativePath: String
    @NSManaged var data: Data?
    @NSManaged var mimeType: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}

@objc(AppPreferenceEntity)
final class AppPreferenceEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var key: String
    @NSManaged var value: String?
    @NSManaged var updatedAt: Date?
}

@objc(DeletionMarkerEntity)
final class DeletionMarkerEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var targetType: String
    @NSManaged var targetID: UUID?
    @NSManaged var createdAt: Date?
}

enum DeletionMarkerTargetType: String {
    case vehicle
    case record
    case reminder
}

enum CoreDataDeletionMarkerStore {
    static func contains(
        _ targetType: DeletionMarkerTargetType,
        targetID: UUID,
        in context: NSManagedObjectContext
    ) throws -> Bool {
        let request = NSFetchRequest<DeletionMarkerEntity>(
            entityName: "DeletionMarkerEntity"
        )
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "targetType == %@", targetType.rawValue),
            NSPredicate(format: "targetID == %@", targetID as CVarArg)
        ])
        request.fetchLimit = 1
        return try context.count(for: request) > 0
    }

    static func targetIDs(
        for targetType: DeletionMarkerTargetType,
        in context: NSManagedObjectContext
    ) throws -> Set<UUID> {
        let request = NSFetchRequest<DeletionMarkerEntity>(
            entityName: "DeletionMarkerEntity"
        )
        request.predicate = NSPredicate(
            format: "targetType == %@",
            targetType.rawValue
        )
        return Set(try context.fetch(request).compactMap(\.targetID))
    }

    static func insertIfNeeded(
        _ targetType: DeletionMarkerTargetType,
        targetID: UUID,
        in context: NSManagedObjectContext
    ) throws {
        guard try !contains(targetType, targetID: targetID, in: context) else {
            return
        }
        let marker = DeletionMarkerEntity(context: context)
        marker.id = UUID()
        marker.targetType = targetType.rawValue
        marker.targetID = targetID
        marker.createdAt = .now
    }

    @discardableResult
    static func reconcile(in context: NSManagedObjectContext) throws -> Set<String> {
        let vehicleIDs = try targetIDs(for: .vehicle, in: context)
        let explicitRecordIDs = try targetIDs(for: .record, in: context)
        let reminderIDs = try targetIDs(for: .reminder, in: context)

        var recordIDs = explicitRecordIDs
        var localFilePaths: Set<String> = []
        if !vehicleIDs.isEmpty {
            let vehicleRequest = NSFetchRequest<VehicleEntity>(
                entityName: "VehicleEntity"
            )
            vehicleRequest.predicate = NSPredicate(
                format: "id IN %@",
                Array(vehicleIDs)
            )
            localFilePaths.formUnion(
                nonEmptyFilePaths(
                    try context.fetch(vehicleRequest).compactMap(
                        \.photoIdentifier
                    )
                )
            )

            let request = NSFetchRequest<RecordEntity>(entityName: "RecordEntity")
            request.predicate = NSPredicate(
                format: "vehicleID IN %@",
                Array(vehicleIDs)
            )
            let vehicleRecordIDs = Set(
                try context.fetch(request).compactMap(\.id)
            )
            for recordID in vehicleRecordIDs {
                try insertIfNeeded(.record, targetID: recordID, in: context)
            }
            recordIDs.formUnion(vehicleRecordIDs)
        }

        let documents = try fetchDocuments(
            vehicleIDs: vehicleIDs,
            recordIDs: recordIDs,
            in: context
        )
        let documentPaths = nonEmptyFilePaths(
            documents.map(\.localRelativePath)
        )
        localFilePaths.formUnion(documentPaths)

        try deleteEntities(
            named: "RecordLineItemEntity",
            predicates: recordIDs.isEmpty
                ? []
                : [NSPredicate(format: "recordID IN %@", Array(recordIDs))],
            in: context
        )
        var reminderPredicates = predicates(
            vehicleIDs: vehicleIDs,
            recordIDs: recordIDs
        )
        if !reminderIDs.isEmpty {
            reminderPredicates.append(
                NSPredicate(format: "id IN %@", Array(reminderIDs))
            )
        }
        try deleteEntities(
            named: "ReminderEntity",
            predicates: reminderPredicates,
            in: context
        )
        documents.forEach(context.delete)
        let deletedAssets = try fetchAssets(
            predicates: assetPredicates(
                vehicleIDs: vehicleIDs,
                recordIDs: recordIDs,
                documentPaths: documentPaths
            ),
            in: context
        )
        localFilePaths.formUnion(
            nonEmptyFilePaths(deletedAssets.map(\.relativePath))
        )
        deletedAssets.forEach(context.delete)
        try deleteEntities(
            named: "RecordEntity",
            predicates: predicates(
                vehicleIDs: vehicleIDs,
                recordIDs: recordIDs,
                recordIDKey: "id"
            ),
            in: context
        )
        try deleteEntities(
            named: "VehicleEntity",
            predicates: vehicleIDs.isEmpty
                ? []
                : [NSPredicate(format: "id IN %@", Array(vehicleIDs))],
            in: context
        )
        return localFilePaths
    }

    private static func fetchDocuments(
        vehicleIDs: Set<UUID>,
        recordIDs: Set<UUID>,
        in context: NSManagedObjectContext
    ) throws -> [DocumentEntity] {
        let predicates = predicates(
            vehicleIDs: vehicleIDs,
            recordIDs: recordIDs
        )
        guard !predicates.isEmpty else { return [] }
        let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return try context.fetch(request)
    }

    private static func predicates(
        vehicleIDs: Set<UUID>,
        recordIDs: Set<UUID>,
        recordIDKey: String = "recordID"
    ) -> [NSPredicate] {
        var result: [NSPredicate] = []
        if !vehicleIDs.isEmpty {
            result.append(
                NSPredicate(format: "vehicleID IN %@", Array(vehicleIDs))
            )
        }
        if !recordIDs.isEmpty {
            result.append(
                NSPredicate(
                    format: "\(recordIDKey) IN %@",
                    Array(recordIDs)
                )
            )
        }
        return result
    }

    private static func assetPredicates(
        vehicleIDs: Set<UUID>,
        recordIDs: Set<UUID>,
        documentPaths: Set<String>
    ) -> [NSPredicate] {
        var result: [NSPredicate] = []
        if !vehicleIDs.isEmpty {
            result.append(
                NSPredicate(format: "vehicleID IN %@", Array(vehicleIDs))
            )
        }
        if !recordIDs.isEmpty {
            result.append(
                NSPredicate(format: "recordID IN %@", Array(recordIDs))
            )
        }
        if !documentPaths.isEmpty {
            result.append(
                NSPredicate(
                    format: "relativePath IN %@",
                    Array(documentPaths)
                )
            )
        }
        return result
    }

    private static func fetchAssets(
        predicates: [NSPredicate],
        in context: NSManagedObjectContext
    ) throws -> [AssetEntity] {
        guard !predicates.isEmpty else { return [] }
        let request = NSFetchRequest<AssetEntity>(entityName: "AssetEntity")
        request.predicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: predicates
        )
        return try context.fetch(request)
    }

    private static func nonEmptyFilePaths<S: Sequence>(
        _ paths: S
    ) -> Set<String> where S.Element == String {
        Set(
            paths.filter {
                !$0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            }
        )
    }

    private static func deleteEntities(
        named entityName: String,
        predicates: [NSPredicate],
        in context: NSManagedObjectContext
    ) throws {
        guard !predicates.isEmpty else { return }
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        try context.fetch(request).forEach(context.delete)
    }
}
