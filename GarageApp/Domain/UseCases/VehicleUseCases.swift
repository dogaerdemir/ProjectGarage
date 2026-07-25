//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct CreateVehicleUseCase: Sendable {
    let repository: VehicleRepository

    func execute(
        _ vehicle: Vehicle,
        expectedUpdatedAt: Date? = nil
    ) async throws {
        guard !vehicle.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GarageError.validation("Araç adı boş bırakılamaz.")
        }
        guard !vehicle.make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GarageError.validation("Marka seçin veya manuel olarak girin.")
        }
        guard !vehicle.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GarageError.validation("Model seçin veya manuel olarak girin.")
        }
        guard let modelYear = vehicle.modelYear, (1886...(Calendar.current.component(.year, from: .now) + 1)).contains(modelYear) else {
            throw GarageError.validation("Geçerli bir model yılı seçin.")
        }
        guard vehicle.currentMileage >= 0 else {
            throw GarageError.validation("Kilometre negatif olamaz.")
        }
        try await repository.save(
            vehicle,
            expectedUpdatedAt: expectedUpdatedAt
        )
    }
}

struct UpdateVehicleUseCase: Sendable {
    let repository: VehicleRepository

    func execute(_ vehicle: Vehicle, expectedUpdatedAt: Date? = nil) async throws {
        try await CreateVehicleUseCase(repository: repository).execute(
            vehicle,
            expectedUpdatedAt: expectedUpdatedAt
        )
    }
}

struct UpdateCurrentMileageUseCase: Sendable {
    let repository: VehicleRepository

    func execute(vehicleID: UUID, mileage: Int64) async throws {
        guard mileage >= 0 else {
            throw GarageError.validation("Kilometre negatif olamaz.")
        }
        guard var vehicle = try await repository.vehicle(id: vehicleID) else {
            throw GarageError.notFound
        }
        let expectedUpdatedAt = vehicle.updatedAt
        vehicle.currentMileage = mileage
        vehicle.updatedAt = .now
        try await repository.save(
            vehicle,
            expectedUpdatedAt: expectedUpdatedAt
        )
    }
}

struct DeleteVehicleUseCase: Sendable {
    let repository: VehicleRepository
    let documentRepository: DocumentRepository?
    let reminderRepository: ReminderRepository?
    let storage: FileStorageService?
    let notificationService: NotificationSchedulingService?

    func execute(_ vehicle: Vehicle) async throws {
        let vehicleID = vehicle.id
        let photoPath = vehicle.photoIdentifier
        let documents = try await documentRepository?.fetchDocuments(vehicleID: vehicleID) ?? []
        let documentPaths = documents.map(\.localRelativePath)
        let reminders = try await reminderRepository?
            .fetchReminders(vehicleID: vehicleID) ?? []
        try await repository.delete(
            id: vehicleID,
            expectedUpdatedAt: vehicle.updatedAt
        )
        if let notificationService {
            for reminder in reminders {
                await notificationService.cancel(
                    identifier: reminder.notificationIdentifier
                        ?? "garage.reminder.\(reminder.id.uuidString)"
                )
            }
        }
        if let storage {
            if let photoPath { try? await storage.delete(relativePath: photoPath) }
            for path in documentPaths { try? await storage.delete(relativePath: path) }
        }
    }
}
