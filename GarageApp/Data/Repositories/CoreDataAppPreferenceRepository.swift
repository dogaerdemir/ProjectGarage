//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CoreData

final class CoreDataAppPreferenceRepository: AppPreferenceRepository, @unchecked Sendable {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func value(forKey key: String) async throws -> String? {
        try await persistence.read { context in
            let request = NSFetchRequest<AppPreferenceEntity>(entityName: "AppPreferenceEntity")
            request.predicate = NSPredicate(format: "key == %@", key)
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            request.fetchLimit = 1
            return try context.fetch(request).first?.value
        }
    }

    func save(value: String?, forKey key: String) async throws {
        try await persistence.write { context in
            let request = NSFetchRequest<AppPreferenceEntity>(entityName: "AppPreferenceEntity")
            request.predicate = NSPredicate(format: "key == %@", key)
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            let matches = try context.fetch(request)
            guard let value else {
                matches.forEach(context.delete)
                return
            }
            if let current = matches.first,
               current.id != nil,
               current.updatedAt != nil,
               current.value == value {
                matches.dropFirst().forEach(context.delete)
                return
            }
            let entity = matches.first ?? AppPreferenceEntity(context: context)
            if entity.id == nil { entity.id = UUID() }
            entity.key = key
            entity.value = value
            entity.updatedAt = .now
            matches.dropFirst().forEach(context.delete)
        }
    }
}
