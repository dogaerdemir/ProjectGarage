//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct MonthlyCostChartEntry: Equatable {
    let month: Date
    let shortLabel: String
    let fullLabel: String
    let amountsByType: [RecordType: Decimal]

    var total: Decimal {
        RecordType.costChartTypes.reduce(0) { $0 + (amountsByType[$1] ?? 0) }
    }
}

@MainActor
final class InsightsViewModel {
    struct State {
        var summary: VehicleCostSummary?
        var chartValues: [MonthlyCostChartEntry] = []
        var error: String?
    }

    private let session: AppSession
    private let recordRepository: VehicleRecordRepository
    private var loadGeneration = 0
    private(set) var state = State()
    var onChange: ((State) -> Void)?

    init(session: AppSession, recordRepository: VehicleRecordRepository) {
        self.session = session
        self.recordRepository = recordRepository
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration

        do {
            try await session.reload()
            guard let vehicle = session.selectedVehicle else {
                guard generation == loadGeneration else { return }
                state = State()
                onChange?(state)
                return
            }

            let vehicleID = vehicle.id
            let summary = try await CalculateVehicleCostsUseCase(repository: recordRepository).execute(vehicle: vehicle)
            guard generation == loadGeneration, session.selectedVehicle?.id == vehicleID else { return }

            let calendar = Calendar.current
            let shortFormatter = DateFormatter()
            shortFormatter.locale = Locale(identifier: "tr_TR")
            shortFormatter.dateFormat = "MMM"

            let fullFormatter = DateFormatter()
            fullFormatter.locale = Locale(identifier: "tr_TR")
            fullFormatter.dateFormat = "MMMM yyyy"

            state.summary = summary
            state.chartValues = (0..<12)
                .reversed()
                .compactMap { calendar.date(byAdding: .month, value: -$0, to: .now) }
                .map { date in
                    let components = calendar.dateComponents([.year, .month], from: date)
                    let month = calendar.date(from: components) ?? date
                    return MonthlyCostChartEntry(
                        month: month,
                        shortLabel: shortFormatter.string(from: date).capitalized(with: shortFormatter.locale),
                        fullLabel: fullFormatter.string(from: date).capitalized(with: fullFormatter.locale),
                        amountsByType: summary.monthlyTotalsByType[month] ?? [:]
                    )
                }
            state.error = nil
            onChange?(state)
        } catch {
            guard generation == loadGeneration else { return }
            state.error = error.localizedDescription
            onChange?(state)
        }
    }
}
