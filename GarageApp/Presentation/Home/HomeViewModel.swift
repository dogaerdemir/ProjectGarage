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

    struct State: Equatable {
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
    private var isLoading = false
    private var shouldReloadAfterCurrentLoad = false
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
        guard !isLoading else {
            shouldReloadAfterCurrentLoad = true
            return
        }

        isLoading = true
        repeat {
            shouldReloadAfterCurrentLoad = false
            await performLoad()
        } while shouldReloadAfterCurrentLoad
        isLoading = false
    }

    private func performLoad() async {
        if state.vehicle == nil {
            var loadingState = state
            loadingState.isLoading = true
            loadingState.errorMessage = nil
            publish(loadingState)
        }

        do {
            try await session.reload()
            guard let vehicle = session.selectedVehicle else {
                publish(State())
                return
            }

            var loadedState = State(vehicle: vehicle)
            let records = try await recordRepository.fetchRecords(vehicleID: vehicle.id, types: nil)
            loadedState.recentRecords = Array(records.filter { $0.recordType != .mileage }.prefix(4))
            let reminders = try await EvaluateReminderStatusesUseCase(repository: reminderRepository).execute(vehicle: vehicle)
                .filter { $0.status == .approaching || $0.status == .overdue || $0.status == .active }
                .sorted { reminderSortKey($0, vehicle: vehicle) < reminderSortKey($1, vehicle: vehicle) }
            let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
            loadedState.reminders = reminders.map { reminder in
                ReminderItem(reminder: reminder, recordType: reminder.recordID.flatMap { recordsByID[$0]?.recordType })
            }
            if let photoIdentifier = vehicle.photoIdentifier {
                loadedState.vehicleImageData = try? await fileStorageService.read(relativePath: photoIdentifier)
            }
            let costs = try await CalculateVehicleCostsUseCase(repository: recordRepository).execute(vehicle: vehicle)
            loadedState.monthlyTotal = costs.monthlyTotal
            loadedState.yearlyTotal = costs.yearlyTotal
            publish(loadedState)
        } catch {
            var failedState = state
            failedState.isLoading = false
            failedState.errorMessage = error.localizedDescription
            publish(failedState)
        }
    }

    private func publish(_ newState: State) {
        guard state != newState else { return }
        state = newState
        onChange?(newState)
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
