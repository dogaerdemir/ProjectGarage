//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct CreateRecordUseCase: Sendable {
    let recordRepository: VehicleRecordRepository
    let vehicleRepository: VehicleRepository

    func execute(_ record: VehicleRecord, lineItems: [RecordLineItem] = []) async throws {
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
        if record.recordType == .mileage, let odometer = record.odometer, let vehicle = storedVehicle, odometer < vehicle.currentMileage {
            throw GarageError.mileageCannotDecrease(current: vehicle.currentMileage)
        }
        try await recordRepository.save(record, lineItems: lineItems)
        if let odometer = record.odometer, var vehicle = storedVehicle, odometer > vehicle.currentMileage {
            vehicle.currentMileage = odometer
            vehicle.updatedAt = .now
            try await vehicleRepository.save(vehicle)
        }
    }
}

struct UpdateRecordUseCase: Sendable {
    let recordRepository: VehicleRecordRepository
    let vehicleRepository: VehicleRepository

    func execute(_ record: VehicleRecord, lineItems: [RecordLineItem] = []) async throws {
        guard try await recordRepository.record(id: record.id) != nil else {
            throw GarageError.notFound
        }
        try await CreateRecordUseCase(
            recordRepository: recordRepository,
            vehicleRepository: vehicleRepository
        ).execute(record, lineItems: lineItems)
    }
}

struct DeleteRecordUseCase: Sendable {
    let repository: VehicleRecordRepository
    let documentRepository: DocumentRepository?
    let storage: FileStorageService?

    func execute(recordID: UUID, vehicleID: UUID? = nil) async throws {
        if let documentRepository, let storage, let vehicleID {
            let documents = try await documentRepository.fetchDocuments(vehicleID: vehicleID).filter { $0.recordID == recordID }
            for document in documents {
                try? await storage.delete(relativePath: document.localRelativePath)
                try await documentRepository.delete(id: document.id)
            }
        }
        try await repository.delete(id: recordID)
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
