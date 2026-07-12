//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

enum CoreDataMapper {
    static func vehicle(from entity: VehicleEntity) throws -> Vehicle {
        Vehicle(
            id: entity.id, nickname: entity.nickname, make: entity.make, model: entity.model,
            modelYear: entity.modelYear == 0 ? nil : Int(entity.modelYear),
            fuelType: entity.fuelType.flatMap(FuelType.init(rawValue:)),
            transmissionType: entity.transmissionType.flatMap(TransmissionType.init(rawValue:)),
            plateNumber: entity.plateNumber, vin: entity.vin,
            currentMileage: entity.currentMileage, photoIdentifier: entity.photoIdentifier,
            isArchived: entity.isArchived, createdAt: entity.createdAt, updatedAt: entity.updatedAt
        )
    }

    static func apply(_ vehicle: Vehicle, to entity: VehicleEntity) {
        entity.id = vehicle.id; entity.nickname = vehicle.nickname; entity.make = vehicle.make
        entity.model = vehicle.model; entity.modelYear = Int64(vehicle.modelYear ?? 0)
        entity.fuelType = vehicle.fuelType?.rawValue
        entity.transmissionType = vehicle.transmissionType?.rawValue
        entity.plateNumber = vehicle.plateNumber; entity.vin = vehicle.vin
        entity.currentMileage = vehicle.currentMileage; entity.photoIdentifier = vehicle.photoIdentifier
        entity.isArchived = vehicle.isArchived; entity.createdAt = vehicle.createdAt
        entity.updatedAt = vehicle.updatedAt
    }

    static func record(from entity: RecordEntity) throws -> VehicleRecord {
        guard let type = RecordType(rawValue: entity.recordType) else { throw GarageError.persistence }
        return VehicleRecord(
            id: entity.id, vehicleID: entity.vehicleID, recordType: type, title: entity.title,
            eventDate: entity.eventDate, odometer: entity.hasOdometer ? entity.odometer : nil,
            totalAmount: entity.totalAmount?.decimalValue, currencyCode: entity.currencyCode,
            vendorName: entity.vendorName, notes: entity.notes, source: entity.source,
            liters: entity.liters?.decimalValue, unitPrice: entity.unitPrice?.decimalValue,
            isFullTank: entity.hasFullTankValue ? entity.isFullTank : nil,
            policyType: entity.policyType, policyNumber: entity.policyNumber,
            startDate: entity.startDate, endDate: entity.endDate,
            inspectionType: entity.inspectionType, validityDate: entity.validityDate,
            outcome: entity.outcome, createdAt: entity.createdAt, updatedAt: entity.updatedAt
        )
    }

    static func apply(_ record: VehicleRecord, to entity: RecordEntity) {
        entity.id = record.id; entity.vehicleID = record.vehicleID
        entity.recordType = record.recordType.rawValue; entity.title = record.title
        entity.eventDate = record.eventDate; entity.odometer = record.odometer ?? 0
        entity.hasOdometer = record.odometer != nil
        entity.totalAmount = record.totalAmount.map(NSDecimalNumber.init(decimal:))
        entity.currencyCode = record.currencyCode; entity.vendorName = record.vendorName
        entity.notes = record.notes; entity.source = record.source
        entity.liters = record.liters.map(NSDecimalNumber.init(decimal:))
        entity.unitPrice = record.unitPrice.map(NSDecimalNumber.init(decimal:))
        entity.isFullTank = record.isFullTank ?? false; entity.hasFullTankValue = record.isFullTank != nil
        entity.policyType = record.policyType; entity.policyNumber = record.policyNumber
        entity.startDate = record.startDate; entity.endDate = record.endDate
        entity.inspectionType = record.inspectionType; entity.validityDate = record.validityDate
        entity.outcome = record.outcome; entity.createdAt = record.createdAt; entity.updatedAt = record.updatedAt
    }

    static func lineItem(from entity: RecordLineItemEntity) -> RecordLineItem {
        RecordLineItem(
            id: entity.id, recordID: entity.recordID, name: entity.name,
            category: entity.category, brand: entity.brand, partNumber: entity.partNumber,
            amount: entity.amount?.decimalValue, warrantyEndDate: entity.warrantyEndDate,
            notes: entity.notes, sortOrder: Int(entity.sortOrder)
        )
    }

    static func apply(_ item: RecordLineItem, to entity: RecordLineItemEntity) {
        entity.id = item.id; entity.recordID = item.recordID; entity.name = item.name
        entity.category = item.category; entity.brand = item.brand; entity.partNumber = item.partNumber
        entity.amount = item.amount.map(NSDecimalNumber.init(decimal:))
        entity.warrantyEndDate = item.warrantyEndDate; entity.notes = item.notes
        entity.sortOrder = Int64(item.sortOrder)
    }

    static func reminder(from entity: ReminderEntity) throws -> Reminder {
        guard let status = ReminderStatus(rawValue: entity.status) else { throw GarageError.persistence }
        return Reminder(
            id: entity.id, vehicleID: entity.vehicleID, recordID: entity.recordID,
            title: entity.title, dueDate: entity.dueDate,
            dueMileage: entity.hasDueMileage ? entity.dueMileage : nil, status: status,
            isEnabled: entity.isEnabled, notificationIdentifier: entity.notificationIdentifier,
            createdAt: entity.createdAt, updatedAt: entity.updatedAt, completedAt: entity.completedAt
        )
    }

    static func apply(_ reminder: Reminder, to entity: ReminderEntity) {
        entity.id = reminder.id; entity.vehicleID = reminder.vehicleID; entity.recordID = reminder.recordID
        entity.title = reminder.title; entity.dueDate = reminder.dueDate
        entity.dueMileage = reminder.dueMileage ?? 0; entity.hasDueMileage = reminder.dueMileage != nil
        entity.status = reminder.status.rawValue; entity.isEnabled = reminder.isEnabled
        entity.notificationIdentifier = reminder.notificationIdentifier
        entity.createdAt = reminder.createdAt; entity.updatedAt = reminder.updatedAt
        entity.completedAt = reminder.completedAt
    }

    static func document(from entity: DocumentEntity) throws -> GarageDocument {
        guard let type = DocumentType(rawValue: entity.documentType) else { throw GarageError.persistence }
        return GarageDocument(
            id: entity.id, vehicleID: entity.vehicleID, recordID: entity.recordID,
            documentType: type, displayName: entity.displayName, mimeType: entity.mimeType,
            fileSize: entity.fileSize, localRelativePath: entity.localRelativePath,
            thumbnailRelativePath: entity.thumbnailRelativePath, checksum: entity.checksum,
            createdAt: entity.createdAt
        )
    }

    static func apply(_ document: GarageDocument, to entity: DocumentEntity) {
        entity.id = document.id; entity.vehicleID = document.vehicleID; entity.recordID = document.recordID
        entity.documentType = document.documentType.rawValue; entity.displayName = document.displayName
        entity.mimeType = document.mimeType; entity.fileSize = document.fileSize
        entity.localRelativePath = document.localRelativePath
        entity.thumbnailRelativePath = document.thumbnailRelativePath
        entity.checksum = document.checksum; entity.createdAt = document.createdAt
    }
}
