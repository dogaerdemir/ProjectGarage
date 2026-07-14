//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct CalculateVehicleCostsUseCase: Sendable {
    let repository: VehicleRecordRepository
    var calendar: Calendar = .current

    func execute(vehicle: Vehicle, now: Date = .now) async throws -> VehicleCostSummary {
        let records = try await repository.fetchRecords(vehicleID: vehicle.id, types: nil)
        let costRecords = records.filter { $0.totalAmount != nil }
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let yearInterval = calendar.dateInterval(of: .year, for: now)

        func total(_ records: [VehicleRecord]) -> Decimal {
            records.compactMap(\.totalAmount).reduce(0, +)
        }

        let fuelTotal = total(costRecords.filter { $0.recordType == .fuel })
        let maintenanceTotal = total(costRecords.filter { $0.recordType == .maintenance })
        let allTotal = total(costRecords)

        var monthlyTotals: [Date: Decimal] = [:]
        var totalsByType: [RecordType: Decimal] = [:]
        var monthlyTotalsByType: [Date: [RecordType: Decimal]] = [:]
        for record in costRecords {
            let components = calendar.dateComponents([.year, .month], from: record.eventDate)
            guard let month = calendar.date(from: components), let amount = record.totalAmount else { continue }
            monthlyTotals[month, default: 0] += amount
            totalsByType[record.recordType, default: 0] += amount
            var monthBreakdown = monthlyTotalsByType[month] ?? [:]
            monthBreakdown[record.recordType, default: 0] += amount
            monthlyTotalsByType[month] = monthBreakdown
        }

        let sortedOdometers = records.compactMap(\.odometer).sorted()
        let distance = (sortedOdometers.last ?? vehicle.currentMileage) - (sortedOdometers.first ?? vehicle.currentMileage)
        let costPerKilometer = distance > 0 ? allTotal / Decimal(distance) : nil

        return VehicleCostSummary(
            monthlyTotal: total(costRecords.filter { monthInterval?.contains($0.eventDate) == true }),
            yearlyTotal: total(costRecords.filter { yearInterval?.contains($0.eventDate) == true }),
            fuelTotal: fuelTotal,
            maintenanceTotal: maintenanceTotal,
            otherTotal: allTotal - fuelTotal - maintenanceTotal,
            costPerKilometer: costPerKilometer,
            monthlyTotals: monthlyTotals,
            totalsByType: totalsByType,
            monthlyTotalsByType: monthlyTotalsByType
        )
    }
}

struct CalculateFuelConsumptionUseCase: Sendable {
    let repository: VehicleRecordRepository

    func execute(vehicleID: UUID) async throws -> FuelConsumptionSummary {
        let fuelRecords = try await repository.fetchRecords(vehicleID: vehicleID, types: [.fuel])
            .filter { $0.isFullTank == true && $0.odometer != nil && $0.liters != nil }
            .sorted { ($0.odometer ?? 0) < ($1.odometer ?? 0) }

        guard fuelRecords.count >= 2,
              let firstMileage = fuelRecords.first?.odometer,
              let lastMileage = fuelRecords.last?.odometer,
              lastMileage > firstMileage else {
            throw GarageError.insufficientData
        }

        let consumedLiters = fuelRecords.dropFirst().compactMap(\.liters).reduce(0, +)
        guard consumedLiters > 0 else { throw GarageError.insufficientData }
        let distance = lastMileage - firstMileage
        return FuelConsumptionSummary(
            litersPer100Kilometers: consumedLiters * 100 / Decimal(distance),
            distance: distance,
            consumedLiters: consumedLiters
        )
    }
}
