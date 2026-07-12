//
//  Created by Doğa Erdemir on 12.07.2026.
//

import XCTest
@testable import GarageApp

@MainActor
final class StatisticsUseCaseTests: XCTestCase {
    func testCostSummarySeparatesFuelAndMaintenance() async throws {
        let container = DependencyContainer(inMemory: true)
        let vehicle = Vehicle(nickname: "Test", make: "Test", model: "Araç", currentMileage: 2_000)
        try await container.vehicleRepository.save(vehicle)
        try await container.recordRepository.save(VehicleRecord(vehicleID: vehicle.id, recordType: .fuel, title: "Yakıt", eventDate: .now, odometer: 1_000, totalAmount: 1_000), lineItems: [])
        try await container.recordRepository.save(VehicleRecord(vehicleID: vehicle.id, recordType: .maintenance, title: "Bakım", eventDate: .now, odometer: 2_000, totalAmount: 2_000), lineItems: [])

        let result = try await CalculateVehicleCostsUseCase(repository: container.recordRepository).execute(vehicle: vehicle)

        XCTAssertEqual(result.fuelTotal, 1_000)
        XCTAssertEqual(result.maintenanceTotal, 2_000)
        XCTAssertEqual(result.costPerKilometer, 3)
    }

    func testFuelConsumptionRequiresTwoFullTanks() async throws {
        let container = DependencyContainer(inMemory: true)
        let vehicleID = UUID()
        try await container.recordRepository.save(VehicleRecord(vehicleID: vehicleID, recordType: .fuel, title: "Yakıt", odometer: 1_000, liters: 40, isFullTank: true), lineItems: [])
        try await container.recordRepository.save(VehicleRecord(vehicleID: vehicleID, recordType: .fuel, title: "Yakıt", odometer: 1_500, liters: 30, isFullTank: true), lineItems: [])

        let result = try await CalculateFuelConsumptionUseCase(repository: container.recordRepository).execute(vehicleID: vehicleID)
        XCTAssertEqual(result.litersPer100Kilometers, 6)
    }
}
