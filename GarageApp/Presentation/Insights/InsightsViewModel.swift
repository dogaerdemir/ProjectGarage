//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class InsightsViewModel {
    struct State { var summary: VehicleCostSummary?; var chartValues: [(String, Decimal)] = []; var error: String? }
    private let session: AppSession; private let recordRepository: VehicleRecordRepository
    private(set) var state = State(); var onChange: ((State) -> Void)?
    init(session: AppSession, recordRepository: VehicleRecordRepository) { self.session = session; self.recordRepository = recordRepository }
    func load() async {
        do {
            try await session.reload(); guard let vehicle = session.selectedVehicle else { state = State(); onChange?(state); return }
            let summary = try await CalculateVehicleCostsUseCase(repository: recordRepository).execute(vehicle: vehicle); state.summary = summary
            let calendar = Calendar.current; let formatter = DateFormatter(); formatter.locale = Locale(identifier: "tr_TR"); formatter.dateFormat = "MMM"
            state.chartValues = (0..<12).reversed().compactMap { offset in calendar.date(byAdding: .month, value: -offset, to: .now) }.map { date in
                let components = calendar.dateComponents([.year, .month], from: date); let key = calendar.date(from: components) ?? date; return (formatter.string(from: date), summary.monthlyTotals[key] ?? 0)
            }; state.error = nil; onChange?(state)
        } catch { state.error = error.localizedDescription; onChange?(state) }
    }
}
