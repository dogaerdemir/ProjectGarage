//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

@objc(VehicleEntity)
final class VehicleEntity: NSManagedObject {
    @NSManaged var id: UUID
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
    @NSManaged var isArchived: Bool
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
}

@objc(RecordEntity)
final class RecordEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var vehicleID: UUID
    @NSManaged var recordType: String
    @NSManaged var title: String
    @NSManaged var eventDate: Date
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
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
}

@objc(RecordLineItemEntity)
final class RecordLineItemEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var recordID: UUID
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
    @NSManaged var id: UUID
    @NSManaged var vehicleID: UUID
    @NSManaged var recordID: UUID?
    @NSManaged var title: String
    @NSManaged var dueDate: Date?
    @NSManaged var dueMileage: Int64
    @NSManaged var hasDueMileage: Bool
    @NSManaged var status: String
    @NSManaged var isEnabled: Bool
    @NSManaged var notificationIdentifier: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var completedAt: Date?
}

@objc(DocumentEntity)
final class DocumentEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var vehicleID: UUID
    @NSManaged var recordID: UUID?
    @NSManaged var documentType: String
    @NSManaged var displayName: String
    @NSManaged var mimeType: String
    @NSManaged var fileSize: Int64
    @NSManaged var localRelativePath: String
    @NSManaged var thumbnailRelativePath: String?
    @NSManaged var checksum: String?
    @NSManaged var createdAt: Date
}
