//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class CoreDataDocumentRepository: DocumentRepository, @unchecked Sendable {
    private let persistence: PersistenceController
    init(persistence: PersistenceController) { self.persistence = persistence }

    func fetchDocuments(vehicleID: UUID) async throws -> [GarageDocument] {
        try await persistence.read { context in
            let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            request.predicate = NSPredicate(format: "vehicleID == %@", vehicleID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try context.fetch(request).map(CoreDataMapper.document)
        }
    }

    func document(id: UUID) async throws -> GarageDocument? {
        try await persistence.read { context in
            let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try context.fetch(request).first.map(CoreDataMapper.document)
        }
    }

    func save(_ document: GarageDocument) async throws {
        try await persistence.write { context in
            let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            request.predicate = NSPredicate(format: "id == %@", document.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? DocumentEntity(context: context)
            CoreDataMapper.apply(document, to: entity)
        }
    }

    func delete(id: UUID) async throws {
        try await persistence.write { context in
            let request = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            try context.fetch(request).forEach(context.delete)
        }
    }
}
