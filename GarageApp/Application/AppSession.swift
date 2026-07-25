//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

extension Notification.Name {
    static let garageDataDidChange = Notification.Name("garageDataDidChange")
    static let garagePersistentStoreDidChange = Notification.Name("garagePersistentStoreDidChange")
    static let garageRemoteDataDidReload = Notification.Name("garageRemoteDataDidReload")
    static let selectedVehicleDidChange = Notification.Name("selectedVehicleDidChange")
}

@MainActor
final class AppSession {
    private enum Keys { static let selectedVehicleID = "selectedVehicleID" }

    private let repository: VehicleRepository
    private let preferenceRepository: AppPreferenceRepository?
    private let defaults: UserDefaults
    private var persistentStoreObserver: NSObjectProtocol?
    private var persistentStoreReloadTask: Task<Void, Never>?
    private var persistentStoreReloadPending = false
    private(set) var vehicles: [Vehicle] = []
    private(set) var selectedVehicle: Vehicle?

    init(
        repository: VehicleRepository,
        preferenceRepository: AppPreferenceRepository? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.preferenceRepository = preferenceRepository
        self.defaults = defaults
        persistentStoreObserver = NotificationCenter.default.addObserver(
            forName: .garagePersistentStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.schedulePersistentStoreReload()
            }
        }
    }

    deinit {
        persistentStoreReloadTask?.cancel()
        if let persistentStoreObserver {
            NotificationCenter.default.removeObserver(persistentStoreObserver)
        }
    }

    func reload(persistResolvedSelection: Bool = false) async throws {
        vehicles = try await repository.fetchVehicles(includeArchived: false)
        let cloudValue: String?
        if let preferenceRepository {
            cloudValue = try? await preferenceRepository.value(forKey: Keys.selectedVehicleID)
        } else {
            cloudValue = nil
        }
        let storedValue = cloudValue ?? defaults.string(forKey: Keys.selectedVehicleID)
        let storedID = storedValue.flatMap(UUID.init(uuidString:))
        selectedVehicle = vehicles.first(where: { $0.id == storedID }) ?? vehicles.first
        if let selectedVehicle {
            defaults.set(selectedVehicle.id.uuidString, forKey: Keys.selectedVehicleID)
        } else {
            defaults.removeObject(forKey: Keys.selectedVehicleID)
        }

        if persistResolvedSelection {
            try? await preferenceRepository?.save(
                value: selectedVehicle?.id.uuidString,
                forKey: Keys.selectedVehicleID
            )
        }
    }

    func select(_ vehicle: Vehicle) {
        selectedVehicle = vehicle
        defaults.set(vehicle.id.uuidString, forKey: Keys.selectedVehicleID)
        Task {
            try? await preferenceRepository?.save(
                value: vehicle.id.uuidString,
                forKey: Keys.selectedVehicleID
            )
        }
        NotificationCenter.default.post(name: .selectedVehicleDidChange, object: vehicle.id)
    }

    func dataChanged() async {
        try? await reload(persistResolvedSelection: true)
        NotificationCenter.default.post(name: .garageDataDidChange, object: nil)
    }

    private func schedulePersistentStoreReload() {
        persistentStoreReloadPending = true
        guard persistentStoreReloadTask == nil else { return }
        persistentStoreReloadTask = Task { [weak self] in
            guard let self else { return }
            var didReload = false
            while persistentStoreReloadPending, !Task.isCancelled {
                persistentStoreReloadPending = false
                do {
                    try await reload()
                    didReload = true
                } catch {
                    continue
                }
            }
            persistentStoreReloadTask = nil
            if didReload, !Task.isCancelled {
                NotificationCenter.default.post(name: .garageRemoteDataDidReload, object: nil)
                NotificationCenter.default.post(name: .garageDataDidChange, object: nil)
            }
        }
    }
}
