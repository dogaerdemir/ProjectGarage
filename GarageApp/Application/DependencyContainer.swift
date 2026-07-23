//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class DependencyContainer {
    let persistenceController: PersistenceController
    let vehicleRepository: VehicleRepository
    let recordRepository: VehicleRecordRepository
    let reminderRepository: ReminderRepository
    let documentRepository: DocumentRepository
    let fileStorageService: FileStorageService
    let notificationService: NotificationSchedulingService
    let session: AppSession

    init(inMemory: Bool = false) {
        let persistence = PersistenceController(inMemory: inMemory)
        persistenceController = persistence
        vehicleRepository = CoreDataVehicleRepository(persistence: persistence)
        recordRepository = CoreDataVehicleRecordRepository(persistence: persistence)
        reminderRepository = CoreDataReminderRepository(persistence: persistence)
        documentRepository = CoreDataDocumentRepository(persistence: persistence)
        fileStorageService = LocalFileStorageService()
        notificationService = LocalNotificationSchedulingService()
        session = AppSession(repository: vehicleRepository)
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
