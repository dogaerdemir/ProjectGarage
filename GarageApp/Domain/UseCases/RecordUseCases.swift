//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct CreateRecordUseCase: Sendable {
    let recordRepository: VehicleRecordRepository
    let vehicleRepository: VehicleRepository

    func execute(
        _ record: VehicleRecord,
        lineItems: [RecordLineItem] = [],
        expectedUpdatedAt: Date? = nil
    ) async throws {
        guard !record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GarageError.validation("Kayıt başlığı boş bırakılamaz.")
        }
        if let amount = record.totalAmount, amount < 0 {
            throw GarageError.validation("Tutar negatif olamaz.")
        }
        if let odometer = record.odometer, odometer < 0 {
            throw GarageError.validation("Kilometre negatif olamaz.")
        }

        let storedVehicle = try await vehicleRepository.vehicle(id: record.vehicleID)
        let mileageUpdate: VehicleMileageUpdate?
        if let odometer = record.odometer,
           let vehicle = storedVehicle,
           record.recordType == .mileage || odometer > vehicle.currentMileage {
            mileageUpdate = VehicleMileageUpdate(
                mileage: odometer,
                expectedUpdatedAt: vehicle.updatedAt,
                updatedAt: .now
            )
        } else {
            mileageUpdate = nil
        }
        try await recordRepository.save(
            record,
            lineItems: lineItems,
            expectedUpdatedAt: expectedUpdatedAt,
            vehicleMileageUpdate: mileageUpdate
        )
    }
}

struct UpdateRecordUseCase: Sendable {
    let recordRepository: VehicleRecordRepository
    let vehicleRepository: VehicleRepository

    func execute(
        _ record: VehicleRecord,
        lineItems: [RecordLineItem] = [],
        expectedUpdatedAt: Date? = nil
    ) async throws {
        try await CreateRecordUseCase(
            recordRepository: recordRepository,
            vehicleRepository: vehicleRepository
        ).execute(
            record,
            lineItems: lineItems,
            expectedUpdatedAt: expectedUpdatedAt
        )
    }
}

struct DeleteRecordUseCase: Sendable {
    let repository: VehicleRecordRepository
    let documentRepository: DocumentRepository?
    let reminderRepository: ReminderRepository?
    let storage: FileStorageService?
    let notificationService: NotificationSchedulingService?

    func execute(
        recordID: UUID,
        vehicleID: UUID? = nil,
        expectedUpdatedAt: Date? = nil
    ) async throws {
        var documents: [GarageDocument] = []
        var reminders: [Reminder] = []
        if let documentRepository, let vehicleID {
            documents = try await documentRepository.fetchDocuments(vehicleID: vehicleID).filter { $0.recordID == recordID }
        }
        if let reminderRepository, let vehicleID {
            reminders = try await reminderRepository.fetchReminders(vehicleID: vehicleID)
                .filter { $0.recordID == recordID }
        }
        try await repository.delete(
            id: recordID,
            expectedUpdatedAt: expectedUpdatedAt
        )
        if let notificationService {
            for reminder in reminders {
                await notificationService.cancel(
                    identifier: reminder.notificationIdentifier
                        ?? "garage.reminder.\(reminder.id.uuidString)"
                )
            }
        }
        if let documentRepository, let storage {
            for document in documents {
                try await documentRepository.delete(id: document.id)
                try? await storage.delete(relativePath: document.localRelativePath)
            }
        }
    }
}

struct FetchTimelineUseCase: Sendable {
    let repository: VehicleRecordRepository

    func execute(vehicleID: UUID, types: Set<RecordType>? = nil) async throws -> [VehicleRecord] {
        try await repository.fetchRecords(vehicleID: vehicleID, types: types)
            .sorted { $0.eventDate > $1.eventDate }
    }
}

struct CalculateFuelValuesUseCase: Sendable {
    func execute(liters: Decimal?, unitPrice: Decimal?, total: Decimal?) -> (Decimal?, Decimal?, Decimal?) {
        if let liters, let unitPrice, total == nil { return (liters, unitPrice, liters * unitPrice) }
        if let liters, let total, unitPrice == nil, liters != 0 { return (liters, total / liters, total) }
        if let unitPrice, let total, liters == nil, unitPrice != 0 { return (total / unitPrice, unitPrice, total) }
        return (liters, unitPrice, total)
    }
}
