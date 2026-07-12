//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct CreateVehicleUseCase: Sendable {
    let repository: VehicleRepository

    func execute(_ vehicle: Vehicle) async throws {
        guard !vehicle.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GarageError.validation("Araç adı boş bırakılamaz.")
        }
        guard vehicle.currentMileage >= 0 else {
            throw GarageError.validation("Kilometre negatif olamaz.")
        }
        try await repository.save(vehicle)
    }
}

struct UpdateVehicleUseCase: Sendable {
    let repository: VehicleRepository

    func execute(_ vehicle: Vehicle) async throws {
        guard let existing = try await repository.vehicle(id: vehicle.id) else {
            throw GarageError.notFound
        }
        guard vehicle.currentMileage >= existing.currentMileage else {
            throw GarageError.mileageCannotDecrease(current: existing.currentMileage)
        }
        try await CreateVehicleUseCase(repository: repository).execute(vehicle)
    }
}

struct UpdateCurrentMileageUseCase: Sendable {
    let repository: VehicleRepository

    func execute(vehicleID: UUID, mileage: Int64) async throws {
        guard var vehicle = try await repository.vehicle(id: vehicleID) else {
            throw GarageError.notFound
        }
        guard mileage >= vehicle.currentMileage else {
            throw GarageError.mileageCannotDecrease(current: vehicle.currentMileage)
        }
        vehicle.currentMileage = mileage
        vehicle.updatedAt = .now
        try await repository.save(vehicle)
    }
}

struct DeleteVehicleUseCase: Sendable {
    let repository: VehicleRepository
    let documentRepository: DocumentRepository?
    let reminderRepository: ReminderRepository?
    let storage: FileStorageService?
    let notificationService: NotificationSchedulingService?

    func execute(vehicleID: UUID) async throws {
        if let photoPath = try await repository.vehicle(id: vehicleID)?.photoIdentifier, let storage {
            try? await storage.delete(relativePath: photoPath)
        }
        if let documentRepository, let storage {
            let documents = try await documentRepository.fetchDocuments(vehicleID: vehicleID)
            for document in documents { try? await storage.delete(relativePath: document.localRelativePath) }
        }
        if let reminderRepository, let notificationService {
            let reminders = try await reminderRepository.fetchReminders(vehicleID: vehicleID)
            for reminder in reminders {
                if let identifier = reminder.notificationIdentifier { await notificationService.cancel(identifier: identifier) }
            }
        }
        try await repository.delete(id: vehicleID)
    }
}
