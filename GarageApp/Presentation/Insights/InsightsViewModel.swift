//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

enum InsightsPeriod: Int, Sendable {
    case month
    case year
}

enum InsightsCostCategory: CaseIterable, Hashable, Sendable {
    case fuel
    case maintenance
    case insurance
    case other

    var title: String {
        switch self {
        case .fuel: "Yakıt"
        case .maintenance: "Bakım"
        case .insurance: "Sigorta"
        case .other: "Diğer"
        }
    }

    var symbolName: String {
        switch self {
        case .fuel: RecordType.fuel.symbolName
        case .maintenance: RecordType.maintenance.symbolName
        case .insurance: RecordType.insurance.symbolName
        case .other: "ellipsis"
        }
    }

    static func category(for recordType: RecordType) -> InsightsCostCategory {
        switch recordType {
        case .fuel: .fuel
        case .maintenance: .maintenance
        case .insurance: .insurance
        case .expense, .inspection, .mileage, .note: .other
        }
    }
}

struct InsightsCategoryTotal: Equatable, Sendable {
    let category: InsightsCostCategory
    let amount: Decimal
}

struct MonthlyCostChartEntry: Equatable, Sendable {
    let month: Date
    let shortLabel: String
    let fullLabel: String
    let amountsByCategory: [InsightsCostCategory: Decimal]

    var total: Decimal {
        InsightsCostCategory.allCases.reduce(0) { $0 + (amountsByCategory[$1] ?? 0) }
    }
}

@MainActor
final class InsightsViewModel {
    struct State {
        var hasVehicle = false
        var selectedPeriod: InsightsPeriod = .year
        var total: Decimal = 0
        var distance: Int64?
        var costPerKilometer: Decimal?
        var categoryTotals: [InsightsCategoryTotal] = []
        var chartValues: [MonthlyCostChartEntry] = []
        var isLoading = true
        var error: String?
    }

    private let session: AppSession
    private let recordRepository: VehicleRecordRepository
    private var loadGeneration = 0
    private var summary: VehicleCostSummary?
    private(set) var state = State()
    var onChange: ((State) -> Void)?

    init(session: AppSession, recordRepository: VehicleRecordRepository) {
        self.session = session
        self.recordRepository = recordRepository
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        let selectedPeriod = state.selectedPeriod
        summary = nil
        state.hasVehicle = session.selectedVehicle != nil
        state.total = 0
        state.distance = nil
        state.costPerKilometer = nil
        state.categoryTotals = []
        state.chartValues = []
        state.isLoading = true
        state.error = nil
        onChange?(state)

        do {
            try await session.reload()
            guard let vehicle = session.selectedVehicle else {
                guard generation == loadGeneration else { return }
                summary = nil
                var nextState = State()
                nextState.selectedPeriod = selectedPeriod
                nextState.isLoading = false
                state = nextState
                onChange?(state)
                return
            }

            let vehicleID = vehicle.id
            let loadedSummary = try await CalculateVehicleCostsUseCase(repository: recordRepository).execute(vehicle: vehicle)
            guard generation == loadGeneration, session.selectedVehicle?.id == vehicleID else { return }

            summary = loadedSummary
            state.hasVehicle = true
            state.chartValues = makeChartValues(from: loadedSummary)
            state.isLoading = false
            state.error = nil
            var nextState = state
            applySelectedPeriod(to: &nextState, summary: loadedSummary)
            state = nextState
            onChange?(state)
        } catch {
            guard generation == loadGeneration else { return }
            summary = nil
            var nextState = State()
            nextState.selectedPeriod = selectedPeriod
            nextState.isLoading = false
            nextState.error = error.localizedDescription
            state = nextState
            onChange?(state)
        }
    }

    func selectPeriod(_ period: InsightsPeriod) {
        guard state.selectedPeriod != period else { return }
        state.selectedPeriod = period
        if let summary {
            var nextState = state
            applySelectedPeriod(to: &nextState, summary: summary)
            state = nextState
        }
        onChange?(state)
    }

    private func applySelectedPeriod(to state: inout State, summary: VehicleCostSummary, now: Date = .now) {
        let calendar = Calendar.current
        let totalsByType: [RecordType: Decimal]

        switch state.selectedPeriod {
        case .month:
            state.total = summary.monthlyTotal
            state.distance = summary.monthlyDistance
            let components = calendar.dateComponents([.year, .month], from: now)
            let month = calendar.date(from: components)
            totalsByType = month.flatMap { summary.monthlyTotalsByType[$0] } ?? [:]
        case .year:
            state.total = summary.yearlyTotal
            state.distance = summary.yearlyDistance
            let currentYear = calendar.component(.year, from: now)
            totalsByType = summary.monthlyTotalsByType.reduce(into: [:]) { result, entry in
                guard calendar.component(.year, from: entry.key) == currentYear else { return }
                entry.value.forEach { result[$0.key, default: 0] += $0.value }
            }
        }

        if let distance = state.distance, distance > 0 {
            state.costPerKilometer = state.total / Decimal(distance)
        } else {
            state.costPerKilometer = nil
        }

        let groupedTotals = groupTotalsByCategory(totalsByType)
        state.categoryTotals = InsightsCostCategory.allCases.map {
            InsightsCategoryTotal(category: $0, amount: groupedTotals[$0] ?? 0)
        }
    }

    private func makeChartValues(from summary: VehicleCostSummary, now: Date = .now) -> [MonthlyCostChartEntry] {
        let calendar = Calendar.current
        let shortFormatter = DateFormatter()
        shortFormatter.locale = Locale(identifier: "tr_TR")
        shortFormatter.dateFormat = "MMM"

        let fullFormatter = DateFormatter()
        fullFormatter.locale = Locale(identifier: "tr_TR")
        fullFormatter.dateFormat = "MMMM yyyy"

        return (0..<12)
            .reversed()
            .compactMap { calendar.date(byAdding: .month, value: -$0, to: now) }
            .map { date in
                let components = calendar.dateComponents([.year, .month], from: date)
                let month = calendar.date(from: components) ?? date
                return MonthlyCostChartEntry(
                    month: month,
                    shortLabel: shortFormatter.string(from: date).capitalized(with: shortFormatter.locale),
                    fullLabel: fullFormatter.string(from: date).capitalized(with: fullFormatter.locale),
                    amountsByCategory: groupTotalsByCategory(summary.monthlyTotalsByType[month] ?? [:])
                )
            }
    }

    private func groupTotalsByCategory(_ totalsByType: [RecordType: Decimal]) -> [InsightsCostCategory: Decimal] {
        totalsByType.reduce(into: [:]) { result, entry in
            let category = InsightsCostCategory.category(for: entry.key)
            result[category, default: 0] += entry.value
        }
    }
}
