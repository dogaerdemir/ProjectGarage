//
//  Created by Doğa Erdemir on 24.07.2026.
//

import Foundation

protocol VehicleCatalogService: Sendable {
    func catalog() async throws -> VehicleCatalog
}

actor BundledVehicleCatalogService: VehicleCatalogService {
    private enum Constants {
        static let resourceName = "vehicle_catalog_tr"
    }

    private let bundle: Bundle
    private let decoder = JSONDecoder()
    private var loadedCatalog: VehicleCatalog?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func catalog() async throws -> VehicleCatalog {
        if let loadedCatalog { return loadedCatalog }

        guard let url = bundle.url(
            forResource: Constants.resourceName,
            withExtension: "json"
        ) else {
            throw GarageError.persistence
        }

        let data = try Data(contentsOf: url)
        let catalog = try decoder.decode(VehicleCatalog.self, from: data)
        guard isValid(catalog) else { throw GarageError.persistence }
        loadedCatalog = catalog
        return catalog
    }

    private func isValid(_ catalog: VehicleCatalog) -> Bool {
        guard catalog.schemaVersion > 0,
              catalog.catalogVersion > 0,
              ISO8601DateFormatter().date(from: catalog.updatedAt) != nil,
              (1...200).contains(catalog.makes.count) else {
            return false
        }

        var identifiers = Set<String>()
        var modelCount = 0
        for make in catalog.makes {
            guard isValidIdentifier(make.id),
                  identifiers.insert(make.id).inserted,
                  !make.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !make.models.isEmpty else {
                return false
            }
            modelCount += make.models.count
            for model in make.models {
                guard isValidIdentifier(model.id),
                      identifiers.insert(model.id).inserted,
                      !model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return false
                }
            }
        }
        return modelCount <= 2_000
    }

    private func isValidIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 96 else { return false }
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_."
        )
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }
}
