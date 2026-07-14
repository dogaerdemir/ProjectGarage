//
//  Created by Doğa Erdemir on 12.07.2026.
//

import XCTest
@testable import GarageApp

@MainActor
final class VehicleUseCaseTests: XCTestCase {
    func testCreateAndFetchVehicleUsingInMemoryStore() async throws {
        let container = DependencyContainer(inMemory: true)
        let vehicle = Vehicle(nickname: "Aile Arabası", make: "Toyota", model: "Corolla", currentMileage: 42_000)

        try await CreateVehicleUseCase(repository: container.vehicleRepository).execute(vehicle)
        let fetched = try await container.vehicleRepository.vehicle(id: vehicle.id)

        XCTAssertEqual(fetched, vehicle)
    }

    func testMileageCanBeCorrectedToLowerValue() async throws {
        let container = DependencyContainer(inMemory: true)
        let vehicle = Vehicle(nickname: "Aracım", make: "Fiat", model: "Egea", currentMileage: 50_000)
        try await container.vehicleRepository.save(vehicle)

        try await UpdateCurrentMileageUseCase(repository: container.vehicleRepository)
            .execute(vehicleID: vehicle.id, mileage: 49_000)

        let updated = try await container.vehicleRepository.vehicle(id: vehicle.id)
        XCTAssertEqual(updated?.currentMileage, 49_000)
    }

    func testEditingVehicleCanCorrectMileageToLowerValue() async throws {
        let container = DependencyContainer(inMemory: true)
        var vehicle = Vehicle(nickname: "Aracım", make: "Fiat", model: "Egea", currentMileage: 50_000)
        try await container.vehicleRepository.save(vehicle)
        vehicle.currentMileage = 49_000

        try await UpdateVehicleUseCase(repository: container.vehicleRepository).execute(vehicle)

        let updated = try await container.vehicleRepository.vehicle(id: vehicle.id)
        XCTAssertEqual(updated?.currentMileage, 49_000)
    }
}
