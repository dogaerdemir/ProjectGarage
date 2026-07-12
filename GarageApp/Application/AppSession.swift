//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

extension Notification.Name {
    static let garageDataDidChange = Notification.Name("garageDataDidChange")
    static let selectedVehicleDidChange = Notification.Name("selectedVehicleDidChange")
}

@MainActor
final class AppSession {
    private enum Keys { static let selectedVehicleID = "selectedVehicleID" }

    private let repository: VehicleRepository
    private let defaults: UserDefaults
    private(set) var vehicles: [Vehicle] = []
    private(set) var selectedVehicle: Vehicle?

    init(repository: VehicleRepository, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
    }

    func reload() async throws {
        vehicles = try await repository.fetchVehicles(includeArchived: false)
        let storedID = defaults.string(forKey: Keys.selectedVehicleID).flatMap(UUID.init(uuidString:))
        selectedVehicle = vehicles.first(where: { $0.id == storedID }) ?? vehicles.first
        if let selectedVehicle {
            defaults.set(selectedVehicle.id.uuidString, forKey: Keys.selectedVehicleID)
        } else {
            defaults.removeObject(forKey: Keys.selectedVehicleID)
        }
    }

    func select(_ vehicle: Vehicle) {
        selectedVehicle = vehicle
        defaults.set(vehicle.id.uuidString, forKey: Keys.selectedVehicleID)
        NotificationCenter.default.post(name: .selectedVehicleDidChange, object: vehicle.id)
    }

    func dataChanged() async {
        try? await reload()
        NotificationCenter.default.post(name: .garageDataDidChange, object: nil)
    }
}
