//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

protocol VehicleRepository: Sendable {
    func fetchVehicles(includeArchived: Bool) async throws -> [Vehicle]
    func vehicle(id: UUID) async throws -> Vehicle?
    func save(_ vehicle: Vehicle) async throws
    func delete(id: UUID) async throws
}

protocol VehicleRecordRepository: Sendable {
    func fetchRecords(vehicleID: UUID, types: Set<RecordType>?) async throws -> [VehicleRecord]
    func record(id: UUID) async throws -> VehicleRecord?
    func save(_ record: VehicleRecord, lineItems: [RecordLineItem]) async throws
    func lineItems(recordID: UUID) async throws -> [RecordLineItem]
    func delete(id: UUID) async throws
}

protocol ReminderRepository: Sendable {
    func fetchReminders(vehicleID: UUID) async throws -> [Reminder]
    func save(_ reminder: Reminder) async throws
    func delete(id: UUID) async throws
}

protocol DocumentRepository: Sendable {
    func fetchDocuments(vehicleID: UUID) async throws -> [GarageDocument]
    func document(id: UUID) async throws -> GarageDocument?
    func save(_ document: GarageDocument) async throws
    func delete(id: UUID) async throws
}

protocol FileStorageService: Sendable {
    func save(data: Data, vehicleID: UUID, fileExtension: String) async throws -> String
    func read(relativePath: String) async throws -> Data
    func delete(relativePath: String) async throws
}

protocol NotificationSchedulingService: Sendable {
    func requestAuthorizationIfNeeded() async throws -> Bool
    func schedule(reminder: Reminder) async throws -> String?
    func cancel(identifier: String) async
}
