//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct VehicleMileageUpdate: Sendable {
    let mileage: Int64
    let expectedUpdatedAt: Date
    let updatedAt: Date
}

protocol VehicleRepository: Sendable {
    func fetchVehicles(includeArchived: Bool) async throws -> [Vehicle]
    func vehicle(id: UUID) async throws -> Vehicle?
    func save(_ vehicle: Vehicle, expectedUpdatedAt: Date?) async throws
    func delete(id: UUID, expectedUpdatedAt: Date?) async throws
}

protocol VehicleRecordRepository: Sendable {
    func fetchRecords(vehicleID: UUID, types: Set<RecordType>?) async throws -> [VehicleRecord]
    func record(id: UUID) async throws -> VehicleRecord?
    func save(
        _ record: VehicleRecord,
        lineItems: [RecordLineItem],
        expectedUpdatedAt: Date?,
        vehicleMileageUpdate: VehicleMileageUpdate?
    ) async throws
    func lineItems(recordID: UUID) async throws -> [RecordLineItem]
    func delete(id: UUID, expectedUpdatedAt: Date?) async throws
}

protocol ReminderRepository: Sendable {
    func fetchReminders(vehicleID: UUID) async throws -> [Reminder]
    func save(_ reminder: Reminder, expectedUpdatedAt: Date?) async throws
    func delete(id: UUID, expectedUpdatedAt: Date?) async throws
}

extension VehicleRepository {
    func save(_ vehicle: Vehicle) async throws {
        try await save(vehicle, expectedUpdatedAt: nil)
    }

    func delete(id: UUID) async throws {
        try await delete(id: id, expectedUpdatedAt: nil)
    }
}

extension VehicleRecordRepository {
    func save(
        _ record: VehicleRecord,
        lineItems: [RecordLineItem]
    ) async throws {
        try await save(
            record,
            lineItems: lineItems,
            expectedUpdatedAt: nil,
            vehicleMileageUpdate: nil
        )
    }

    func delete(id: UUID) async throws {
        try await delete(id: id, expectedUpdatedAt: nil)
    }
}

extension ReminderRepository {
    func save(_ reminder: Reminder) async throws {
        try await save(reminder, expectedUpdatedAt: nil)
    }

    func delete(id: UUID) async throws {
        try await delete(id: id, expectedUpdatedAt: nil)
    }
}

protocol DocumentRepository: Sendable {
    func fetchDocuments(vehicleID: UUID) async throws -> [GarageDocument]
    func document(id: UUID) async throws -> GarageDocument?
    func save(_ document: GarageDocument) async throws
    func delete(id: UUID) async throws
}

protocol FileStorageService: Sendable {
    func save(
        data: Data,
        vehicleID: UUID,
        recordID: UUID?,
        fileExtension: String
    ) async throws -> String
    func read(relativePath: String) async throws -> Data
    func delete(relativePath: String) async throws
}

extension FileStorageService {
    func save(
        data: Data,
        vehicleID: UUID,
        fileExtension: String
    ) async throws -> String {
        try await save(
            data: data,
            vehicleID: vehicleID,
            recordID: nil,
            fileExtension: fileExtension
        )
    }
}

protocol AppPreferenceRepository: Sendable {
    func value(forKey key: String) async throws -> String?
    func save(value: String?, forKey key: String) async throws
}

protocol NotificationSchedulingService: Sendable {
    func requestAuthorizationIfNeeded() async throws -> Bool
    func schedule(reminder: Reminder) async throws -> String?
    func cancel(identifier: String) async
    func reconcile(reminders: [Reminder]) async
}
