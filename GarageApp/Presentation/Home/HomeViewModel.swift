//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class HomeViewModel {
    struct ReminderItem: Equatable {
        let reminder: Reminder
        let recordType: RecordType?
    }

    struct State {
        var vehicle: Vehicle?
        var vehicleImageData: Data?
        var recentRecords: [VehicleRecord] = []
        var reminders: [ReminderItem] = []
        var monthlyTotal: Decimal = 0
        var yearlyTotal: Decimal = 0
        var isLoading = false
        var errorMessage: String?
    }

    private let session: AppSession
    private let vehicleRepository: VehicleRepository
    private let recordRepository: VehicleRecordRepository
    private let reminderRepository: ReminderRepository
    private let fileStorageService: FileStorageService
    private(set) var state = State()
    var onChange: ((State) -> Void)?

    init(
        session: AppSession,
        vehicleRepository: VehicleRepository,
        recordRepository: VehicleRecordRepository,
        reminderRepository: ReminderRepository,
        fileStorageService: FileStorageService = LocalFileStorageService()
    ) {
        self.session = session; self.vehicleRepository = vehicleRepository
        self.recordRepository = recordRepository; self.reminderRepository = reminderRepository
        self.fileStorageService = fileStorageService
    }

    func load() async {
        state = State(isLoading: true); onChange?(state)
        defer { state.isLoading = false; onChange?(state) }
        do {
            try await session.reload()
            guard let vehicle = session.selectedVehicle else { state = State(); return }
            state.vehicle = vehicle
            state.vehicleImageData = nil
            state.recentRecords = []
            state.reminders = []
            state.monthlyTotal = 0
            state.yearlyTotal = 0
            state.errorMessage = nil
            let records = try await recordRepository.fetchRecords(vehicleID: vehicle.id, types: nil)
            state.recentRecords = Array(records.filter { $0.recordType != .mileage }.prefix(4))
            let reminders = try await EvaluateReminderStatusesUseCase(repository: reminderRepository).execute(vehicle: vehicle)
                .filter { $0.status == .approaching || $0.status == .overdue || $0.status == .active }
                .sorted { reminderSortKey($0, vehicle: vehicle) < reminderSortKey($1, vehicle: vehicle) }
            let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
            state.reminders = reminders.map { reminder in
                ReminderItem(reminder: reminder, recordType: reminder.recordID.flatMap { recordsByID[$0]?.recordType })
            }
            if let photoIdentifier = vehicle.photoIdentifier {
                state.vehicleImageData = try? await fileStorageService.read(relativePath: photoIdentifier)
            } else {
                state.vehicleImageData = nil
            }
            let costs = try await CalculateVehicleCostsUseCase(repository: recordRepository).execute(vehicle: vehicle)
            state.monthlyTotal = costs.monthlyTotal; state.yearlyTotal = costs.yearlyTotal
            state.errorMessage = nil
        } catch { state.errorMessage = error.localizedDescription }
    }

    private func reminderSortKey(_ reminder: Reminder, vehicle: Vehicle) -> Double {
        let statusPriority: Double = switch reminder.status {
        case .overdue: 0
        case .approaching: 1
        case .active: 2
        case .completed, .cancelled: 3
        }
        let dateDistance = reminder.dueDate.map { max($0.timeIntervalSinceNow, 0) / 86_400 } ?? .greatestFiniteMagnitude
        let mileageDistance = reminder.dueMileage.map { Double(max($0 - vehicle.currentMileage, 0)) / 100 } ?? .greatestFiniteMagnitude
        return statusPriority * 1_000_000 + min(dateDistance, mileageDistance)
    }
}
