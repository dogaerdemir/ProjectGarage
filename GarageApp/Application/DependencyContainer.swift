//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class DependencyContainer {
    private static let cloudContainerIdentifier = "iCloud.com.dogaerdemir.otohafiza"

    let persistenceController: PersistenceController
    let vehicleRepository: VehicleRepository
    let recordRepository: VehicleRecordRepository
    let reminderRepository: ReminderRepository
    let documentRepository: DocumentRepository
    let preferenceRepository: AppPreferenceRepository
    let assetRepository: AssetRepository
    let fileStorageService: FileStorageService
    let legacyAssetMigrator: LegacyAssetMigrator
    let vehicleCatalogService: VehicleCatalogService
    let nearbyPlacesService: NearbyPlacesService
    let cloudSyncController: CloudSyncController
    let notificationService: NotificationSchedulingService
    let session: AppSession

    convenience init(inMemory: Bool = false) {
        let requestedCloudSync = !inMemory
            && CloudSyncController.preferredCloudSyncEnabled()
            && CloudSyncController.legacyAssetsArePrepared()
        let persistence = PersistenceController(
            inMemory: inMemory,
            cloudSyncEnabled: requestedCloudSync,
            cloudContainerIdentifier: Self.cloudContainerIdentifier
        )
        self.init(persistence: persistence, inMemory: inMemory)
    }

    static func makeForApplication(inMemory: Bool = false) async -> DependencyContainer {
        guard !inMemory else { return DependencyContainer(inMemory: true) }
        let requestedCloudSync = CloudSyncController.preferredCloudSyncEnabled()
            && CloudSyncController.legacyAssetsArePrepared()
        let identifier = cloudContainerIdentifier
        let persistence = await Task.detached(priority: .userInitiated) {
            PersistenceController(
                cloudSyncEnabled: requestedCloudSync,
                cloudContainerIdentifier: identifier
            )
        }.value
        return DependencyContainer(persistence: persistence, inMemory: false)
    }

    private init(persistence: PersistenceController, inMemory: Bool) {
        persistenceController = persistence
        vehicleRepository = CoreDataVehicleRepository(persistence: persistence)
        recordRepository = CoreDataVehicleRecordRepository(persistence: persistence)
        reminderRepository = CoreDataReminderRepository(persistence: persistence)
        documentRepository = CoreDataDocumentRepository(persistence: persistence)
        preferenceRepository = CoreDataAppPreferenceRepository(persistence: persistence)
        let localStorage = LocalFileStorageService()
        let coreDataAssetRepository = CoreDataAssetRepository(persistence: persistence)
        assetRepository = coreDataAssetRepository
        fileStorageService = AssetBackedFileStorageService(
            localStorage: localStorage,
            assetRepository: coreDataAssetRepository
        )
        legacyAssetMigrator = LegacyAssetMigrator(
            persistence: persistence,
            legacyLocalStorage: localStorage,
            assetRepository: coreDataAssetRepository
        )
        vehicleCatalogService = BundledVehicleCatalogService()
        nearbyPlacesService = MapKitNearbyPlacesService()
        cloudSyncController = CloudSyncController(
            persistentContainer: persistence.container,
            cloudContainerIdentifier: Self.cloudContainerIdentifier,
            activeConfigurationIsCloudEnabled: persistence.isCloudSyncActive,
            legacyAssetMigrator: legacyAssetMigrator,
            requiresLegacyAssetPreparation: !inMemory,
            startupError: persistence.cloudStartupError
        )
        notificationService = LocalNotificationSchedulingService()
        session = AppSession(
            repository: vehicleRepository,
            preferenceRepository: preferenceRepository
        )
    }

    @MainActor func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            session: session,
            vehicleRepository: vehicleRepository,
            recordRepository: recordRepository,
            reminderRepository: reminderRepository,
            fileStorageService: fileStorageService
        )
    }

    @MainActor func makeTimelineViewModel() -> TimelineViewModel {
        TimelineViewModel(session: session, recordRepository: recordRepository, documentRepository: documentRepository)
    }

    @MainActor func makeDocumentsViewModel() -> DocumentsViewModel {
        DocumentsViewModel(
            session: session,
            documentRepository: documentRepository,
            recordRepository: recordRepository
        )
    }

    @MainActor func makeInsightsViewModel() -> InsightsViewModel {
        InsightsViewModel(session: session, recordRepository: recordRepository)
    }
}
