//
//  Created by Doğa Erdemir on 12.07.2026.
//

import XCTest
@testable import GarageApp

@MainActor
final class RecordUseCaseTests: XCTestCase {
    func testHigherRecordMileageUpdatesVehicle() async throws {
        let container = DependencyContainer(inMemory: true)
        let vehicle = Vehicle(nickname: "Aracım", make: "Renault", model: "Clio", currentMileage: 10_000)
        try await container.vehicleRepository.save(vehicle)
        let record = VehicleRecord(vehicleID: vehicle.id, recordType: .maintenance, title: "Periyodik bakım", odometer: 12_000)

        try await CreateRecordUseCase(
            recordRepository: container.recordRepository,
            vehicleRepository: container.vehicleRepository
        ).execute(record)

        let updated = try await container.vehicleRepository.vehicle(id: vehicle.id)
        XCTAssertEqual(updated?.currentMileage, 12_000)
    }

    func testFuelValueCalculation() {
        let result = CalculateFuelValuesUseCase().execute(liters: 40, unitPrice: 50, total: nil)
        XCTAssertEqual(result.2, 2_000)
    }

    func testMileageRecordCannotDecreaseCurrentMileage() async throws {
        let container = DependencyContainer(inMemory: true)
        let vehicle = Vehicle(nickname: "Aracım", make: "Test", model: "Test", currentMileage: 10_000)
        try await container.vehicleRepository.save(vehicle)
        let record = VehicleRecord(vehicleID: vehicle.id, recordType: .mileage, title: "Kilometre", odometer: 9_000)

        await XCTAssertThrowsErrorAsync {
            try await CreateRecordUseCase(recordRepository: container.recordRepository, vehicleRepository: container.vehicleRepository).execute(record)
        }
    }
}
