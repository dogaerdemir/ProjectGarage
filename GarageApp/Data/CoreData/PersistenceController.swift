//
//  Created by Doğa Erdemir on 12.07.2026.
//

import CoreData

final class PersistenceController: @unchecked Sendable {
    let container: NSPersistentCloudKitContainer
    let isCloudSyncActive: Bool
    let cloudStartupError: Error?
    private let deletionMarkerReconciler: DeletionMarkerReconciler
    private var remoteChangeObserver: NSObjectProtocol?

    init(
        inMemory: Bool = false,
        cloudSyncEnabled: Bool = false,
        cloudContainerIdentifier: String = "iCloud.com.dogaerdemir.mycarapp"
    ) {
        var cloudIsActive = cloudSyncEnabled && !inMemory
        var startupError: Error?
        var selectedContainer = Self.makeContainer(
            inMemory: inMemory,
            cloudSyncEnabled: cloudIsActive,
            cloudContainerIdentifier: cloudContainerIdentifier
        )
        let initialLoadError = Self.loadStores(in: selectedContainer)
        if let initialLoadError, cloudIsActive {
            startupError = initialLoadError
            cloudIsActive = false
            selectedContainer = Self.makeContainer(
                inMemory: false,
                cloudSyncEnabled: false,
                cloudContainerIdentifier: cloudContainerIdentifier
            )
            let localFallbackError = Self.loadStores(in: selectedContainer)
            if let localFallbackError {
                fatalError("Core Data store could not be loaded: \(localFallbackError.localizedDescription)")
            }
        } else if let initialLoadError {
            startupError = initialLoadError
            fatalError("Core Data store could not be loaded: \(initialLoadError.localizedDescription)")
        }

        let startupDeletionPaths = Self.reconcileDeletionMarkersSynchronously(
            in: selectedContainer
        )
        container = selectedContainer
        isCloudSyncActive = cloudIsActive
        cloudStartupError = startupError
        deletionMarkerReconciler = DeletionMarkerReconciler(
            container: selectedContainer,
            pendingLocalFilePaths: startupDeletionPaths
        )
        container.viewContext.performAndWait {
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            container.viewContext.name = "GarageViewContext"
            container.viewContext.transactionAuthor = "ProjectGarage.App"
        }
        observeRemoteChanges()
        let reconciler = deletionMarkerReconciler
        Task {
            try? await reconciler.reconcile()
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .garagePersistentStoreDidChange,
                    object: nil
                )
            }
        }
    }

    deinit {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
    }

    func read<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.viewContext
        return try await context.perform { try operation(context) }
    }

    func backgroundRead<T>(
        _ operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    continuation.resume(returning: try operation(context))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func write<T>(
        rejectingConflictsWithMessage conflictMessage: String? = nil,
        _ operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                context.mergePolicy = conflictMessage == nil
                    ? NSMergeByPropertyObjectTrumpMergePolicy
                    : NSErrorMergePolicy
                do {
                    let result = try operation(context)
                    if context.hasChanges { try context.save() }
                    continuation.resume(returning: result)
                } catch {
                    context.rollback()
                    if let conflictMessage,
                       Self.isPersistentStoreConflict(error) {
                        continuation.resume(
                            throwing: GarageError.validation(conflictMessage)
                        )
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func pendingDeletionMarkerLocalFilePaths() async -> [String] {
        await deletionMarkerReconciler.pendingFilePaths()
    }

    func markDeletionMarkerLocalFilePathCleaned(_ relativePath: String) async {
        await deletionMarkerReconciler.markFilePathCleaned(relativePath)
    }

    private static func configureStoreDescription(_ description: NSPersistentStoreDescription) {
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    }

    private static func makeContainer(
        inMemory: Bool,
        cloudSyncEnabled: Bool,
        cloudContainerIdentifier: String
    ) -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "GarageModel")
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
            return container
        }

        guard let description = container.persistentStoreDescriptions.first else {
            return container
        }
        configureStoreDescription(description)
        if cloudSyncEnabled {
            let options = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudContainerIdentifier
            )
            options.databaseScope = .private
            description.cloudKitContainerOptions = options
        } else {
            description.cloudKitContainerOptions = nil
        }
        return container
    }

    private static func loadStores(in container: NSPersistentCloudKitContainer) -> Error? {
        let group = DispatchGroup()
        let lock = NSLock()
        var receivedError: Error?
        let descriptionCount = max(container.persistentStoreDescriptions.count, 1)
        for _ in 0..<descriptionCount { group.enter() }
        container.loadPersistentStores { _, error in
            if let error {
                lock.lock()
                receivedError = receivedError ?? error
                lock.unlock()
            }
            group.leave()
        }
        group.wait()
        return receivedError
    }

    private static func isPersistentStoreConflict(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain,
           error.code == NSManagedObjectMergeError
            || error.code == NSPersistentStoreSaveConflictsError {
            return true
        }
        if error.userInfo[NSPersistentStoreSaveConflictsErrorKey] != nil {
            return true
        }
        let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] ?? []
        return detailedErrors.contains { isPersistentStoreConflict($0) }
    }

    private static func reconcileDeletionMarkersSynchronously(
        in container: NSPersistentCloudKitContainer
    ) -> Set<String> {
        let group = DispatchGroup()
        let lock = NSLock()
        var localFilePaths: Set<String> = []
        group.enter()
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            defer { group.leave() }
            do {
                let paths = try CoreDataDeletionMarkerStore.reconcile(in: context)
                if context.hasChanges {
                    try context.save()
                }
                lock.lock()
                localFilePaths.formUnion(paths)
                lock.unlock()
            } catch {
                context.rollback()
            }
        }
        group.wait()
        return localFilePaths
    }

    private func observeRemoteChanges() {
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: nil
        ) { [weak self] _ in
            Task {
                guard let self else { return }
                try? await self.deletionMarkerReconciler.reconcile()
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .garagePersistentStoreDidChange,
                        object: nil
                    )
                }
            }
        }
    }
}

private actor DeletionMarkerReconciler {
    private static let pendingPathsDefaultsKey =
        "deletionMarkerPendingLocalFilePaths"

    private let container: NSPersistentCloudKitContainer
    private let defaults: UserDefaults
    private var pendingLocalFilePaths: Set<String>
    private var reconciliationIsRunning = false
    private var rerunRequested = false
    private var waitingReconciliations: [
        CheckedContinuation<Void, Error>
    ] = []

    init(
        container: NSPersistentCloudKitContainer,
        pendingLocalFilePaths: Set<String>,
        defaults: UserDefaults = .standard
    ) {
        self.container = container
        self.defaults = defaults
        let restoredPaths = pendingLocalFilePaths.union(
            defaults.stringArray(forKey: Self.pendingPathsDefaultsKey) ?? []
        )
        self.pendingLocalFilePaths = Set(
            restoredPaths.filter {
                !$0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            }
        )
        defaults.set(
            Array(self.pendingLocalFilePaths),
            forKey: Self.pendingPathsDefaultsKey
        )
    }

    func reconcile() async throws {
        if reconciliationIsRunning {
            rerunRequested = true
            try await withCheckedThrowingContinuation { continuation in
                waitingReconciliations.append(continuation)
            }
            return
        }

        reconciliationIsRunning = true
        do {
            repeat {
                rerunRequested = false
                let paths = try await Self.reconcile(in: container)
                pendingLocalFilePaths.formUnion(paths)
                persistPendingFilePaths()
            } while rerunRequested
            finishReconciliation(with: .success(()))
        } catch {
            finishReconciliation(with: .failure(error))
            throw error
        }
    }

    func pendingFilePaths() -> [String] {
        pendingLocalFilePaths.sorted()
    }

    func markFilePathCleaned(_ relativePath: String) {
        pendingLocalFilePaths.remove(relativePath)
        persistPendingFilePaths()
    }

    private func persistPendingFilePaths() {
        if pendingLocalFilePaths.isEmpty {
            defaults.removeObject(forKey: Self.pendingPathsDefaultsKey)
        } else {
            defaults.set(
                Array(pendingLocalFilePaths),
                forKey: Self.pendingPathsDefaultsKey
            )
        }
    }

    private func finishReconciliation(
        with result: Result<Void, Error>
    ) {
        reconciliationIsRunning = false
        rerunRequested = false
        let continuations = waitingReconciliations
        waitingReconciliations.removeAll()
        continuations.forEach { $0.resume(with: result) }
    }

    private static func reconcile(
        in container: NSPersistentCloudKitContainer
    ) async throws -> Set<String> {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                do {
                    let paths = try CoreDataDeletionMarkerStore.reconcile(
                        in: context
                    )
                    if context.hasChanges {
                        try context.save()
                    }
                    continuation.resume(returning: paths)
                } catch {
                    context.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
