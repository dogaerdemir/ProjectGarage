//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class PersistenceController: @unchecked Sendable {
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "GarageModel")
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data store could not be loaded: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.name = "GarageViewContext"
    }

    func read<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.viewContext
        return try await context.perform { try operation(context) }
    }

    func write<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                do {
                    let result = try operation(context)
                    if context.hasChanges { try context.save() }
                    continuation.resume(returning: result)
                } catch {
                    context.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
