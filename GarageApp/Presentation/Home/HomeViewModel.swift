//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class HomeViewModel {
    struct State {
        var vehicle: Vehicle?
        var recentRecords: [VehicleRecord] = []
        var reminders: [Reminder] = []
        var monthlyTotal: Decimal = 0
        var yearlyTotal: Decimal = 0
        var isLoading = false
        var errorMessage: String?
    }

    private let session: AppSession
    private let vehicleRepository: VehicleRepository
    private let recordRepository: VehicleRecordRepository
    private let reminderRepository: ReminderRepository
    private(set) var state = State()
    var onChange: ((State) -> Void)?

    init(session: AppSession, vehicleRepository: VehicleRepository, recordRepository: VehicleRecordRepository, reminderRepository: ReminderRepository) {
        self.session = session; self.vehicleRepository = vehicleRepository
        self.recordRepository = recordRepository; self.reminderRepository = reminderRepository
    }

    func load() async {
        state.isLoading = true; onChange?(state)
        defer { state.isLoading = false; onChange?(state) }
        do {
            try await session.reload()
            guard let vehicle = session.selectedVehicle else { state = State(); return }
            state.vehicle = vehicle
            let records = try await recordRepository.fetchRecords(vehicleID: vehicle.id, types: nil)
            state.recentRecords = Array(records.prefix(4))
            state.reminders = try await EvaluateReminderStatusesUseCase(repository: reminderRepository).execute(vehicle: vehicle)
                .filter { $0.status == .approaching || $0.status == .overdue || $0.status == .active }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            let costs = try await CalculateVehicleCostsUseCase(repository: recordRepository).execute(vehicle: vehicle)
            state.monthlyTotal = costs.monthlyTotal; state.yearlyTotal = costs.yearlyTotal
            state.errorMessage = nil
        } catch { state.errorMessage = error.localizedDescription }
    }
}
