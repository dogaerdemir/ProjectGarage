//
//  Created by Doğa Erdemir on 24.07.2026.
//

import Foundation

struct VehicleCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let catalogVersion: Int
    let updatedAt: String
    let makes: [VehicleCatalogMake]

    func make(id: String?) -> VehicleCatalogMake? {
        guard let id else { return nil }
        return makes.first { $0.id == id }
    }
}

struct VehicleCatalogMake: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let models: [VehicleCatalogModel]

    func model(id: String?) -> VehicleCatalogModel? {
        guard let id else { return nil }
        return models.first { $0.id == id }
    }
}

struct VehicleCatalogModel: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
}
