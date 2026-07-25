//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

enum FuelType: String, Codable, CaseIterable, Sendable {
    case gasoline, diesel, lpg, hybrid, electric, other
}

enum TransmissionType: String, Codable, CaseIterable, Sendable {
    case manual, automatic, semiAutomatic, other
}

enum RecordType: String, Codable, CaseIterable, Sendable {
    case maintenance, fuel, expense, insurance, inspection, mileage, note
}

enum ReminderStatus: String, Codable, CaseIterable, Sendable {
    case active, approaching, overdue, completed, cancelled
}

enum DocumentType: String, Codable, CaseIterable, Sendable {
    case serviceInvoice, fuelReceipt, insurancePolicy, inspectionDocument
    case warrantyDocument, vehiclePhoto, other
}

struct Vehicle: Identifiable, Equatable, Sendable {
    let id: UUID
    var nickname: String
    var make: String
    var model: String
    var modelYear: Int?
    var fuelType: FuelType?
    var transmissionType: TransmissionType?
    var plateNumber: String?
    var vin: String?
    var currentMileage: Int64
    var photoIdentifier: String?
    var catalogMakeID: String?
    var catalogModelID: String?
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(), nickname: String, make: String, model: String,
        modelYear: Int? = nil, fuelType: FuelType? = nil,
        transmissionType: TransmissionType? = nil, plateNumber: String? = nil,
        vin: String? = nil, currentMileage: Int64 = 0,
        photoIdentifier: String? = nil, catalogMakeID: String? = nil,
        catalogModelID: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id
        self.nickname = nickname
        self.make = make
        self.model = model
        self.modelYear = modelYear
        self.fuelType = fuelType
        self.transmissionType = transmissionType
        self.plateNumber = plateNumber
        self.vin = vin
        self.currentMileage = currentMileage
        self.photoIdentifier = photoIdentifier
        self.catalogMakeID = catalogMakeID
        self.catalogModelID = catalogModelID
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct VehicleRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let vehicleID: UUID
    var recordType: RecordType
    var title: String
    var eventDate: Date
    var odometer: Int64?
    var totalAmount: Decimal?
    var currencyCode: String
    var vendorName: String?
    var notes: String?
    var source: String
    var liters: Decimal?
    var unitPrice: Decimal?
    var isFullTank: Bool?
    var policyType: String?
    var policyNumber: String?
    var startDate: Date?
    var endDate: Date?
    var inspectionType: String?
    var validityDate: Date?
    var outcome: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(), vehicleID: UUID, recordType: RecordType,
        title: String, eventDate: Date = .now, odometer: Int64? = nil,
        totalAmount: Decimal? = nil, currencyCode: String = "TRY",
        vendorName: String? = nil, notes: String? = nil, source: String = "manual",
        liters: Decimal? = nil, unitPrice: Decimal? = nil, isFullTank: Bool? = nil,
        policyType: String? = nil, policyNumber: String? = nil,
        startDate: Date? = nil, endDate: Date? = nil,
        inspectionType: String? = nil, validityDate: Date? = nil,
        outcome: String? = nil, createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id; self.vehicleID = vehicleID; self.recordType = recordType
        self.title = title; self.eventDate = eventDate; self.odometer = odometer
        self.totalAmount = totalAmount; self.currencyCode = currencyCode
        self.vendorName = vendorName; self.notes = notes; self.source = source
        self.liters = liters; self.unitPrice = unitPrice; self.isFullTank = isFullTank
        self.policyType = policyType; self.policyNumber = policyNumber
        self.startDate = startDate; self.endDate = endDate
        self.inspectionType = inspectionType; self.validityDate = validityDate
        self.outcome = outcome; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

struct RecordLineItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let recordID: UUID
    var name: String
    var category: String?
    var brand: String?
    var partNumber: String?
    var amount: Decimal?
    var warrantyEndDate: Date?
    var notes: String?
    var sortOrder: Int

    init(
        id: UUID = UUID(), recordID: UUID, name: String, category: String? = nil,
        brand: String? = nil, partNumber: String? = nil, amount: Decimal? = nil,
        warrantyEndDate: Date? = nil, notes: String? = nil, sortOrder: Int = 0
    ) {
        self.id = id; self.recordID = recordID; self.name = name
        self.category = category; self.brand = brand; self.partNumber = partNumber
        self.amount = amount; self.warrantyEndDate = warrantyEndDate
        self.notes = notes; self.sortOrder = sortOrder
    }
}

struct Reminder: Identifiable, Equatable, Sendable {
    let id: UUID
    let vehicleID: UUID
    var recordID: UUID?
    var title: String
    var dueDate: Date?
    var dueMileage: Int64?
    var status: ReminderStatus
    var isEnabled: Bool
    var notificationIdentifier: String?
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(), vehicleID: UUID, recordID: UUID? = nil,
        title: String, dueDate: Date? = nil, dueMileage: Int64? = nil,
        status: ReminderStatus = .active, isEnabled: Bool = true,
        notificationIdentifier: String? = nil, createdAt: Date = .now,
        updatedAt: Date = .now, completedAt: Date? = nil
    ) {
        self.id = id; self.vehicleID = vehicleID; self.recordID = recordID
        self.title = title; self.dueDate = dueDate; self.dueMileage = dueMileage
        self.status = status; self.isEnabled = isEnabled
        self.notificationIdentifier = notificationIdentifier
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

struct GarageDocument: Identifiable, Equatable, Sendable {
    let id: UUID
    let vehicleID: UUID
    var recordID: UUID?
    var documentType: DocumentType
    var displayName: String
    var mimeType: String
    var fileSize: Int64
    var localRelativePath: String
    var thumbnailRelativePath: String?
    var checksum: String?
    let createdAt: Date

    init(
        id: UUID = UUID(), vehicleID: UUID, recordID: UUID? = nil,
        documentType: DocumentType, displayName: String, mimeType: String,
        fileSize: Int64, localRelativePath: String, thumbnailRelativePath: String? = nil,
        checksum: String? = nil, createdAt: Date = .now
    ) {
        self.id = id; self.vehicleID = vehicleID; self.recordID = recordID
        self.documentType = documentType; self.displayName = displayName
        self.mimeType = mimeType; self.fileSize = fileSize
        self.localRelativePath = localRelativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.checksum = checksum; self.createdAt = createdAt
    }
}

struct VehicleCostSummary: Equatable, Sendable {
    var monthlyTotal: Decimal
    var yearlyTotal: Decimal
    var fuelTotal: Decimal
    var maintenanceTotal: Decimal
    var otherTotal: Decimal
    var costPerKilometer: Decimal?
    var monthlyDistance: Int64?
    var yearlyDistance: Int64?
    var monthlyTotals: [Date: Decimal]
    var totalsByType: [RecordType: Decimal]
    var monthlyTotalsByType: [Date: [RecordType: Decimal]]
}

struct FuelConsumptionSummary: Equatable, Sendable {
    let litersPer100Kilometers: Decimal
    let distance: Int64
    let consumedLiters: Decimal
}
