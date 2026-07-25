//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CloudKit
import CoreData
import Foundation

@MainActor
final class CloudSyncMonitor {
    private enum Operation: Hashable {
        case setup
        case importData
        case exportData

        init(_ eventType: NSPersistentCloudKitContainer.EventType) {
            switch eventType {
            case .setup: self = .setup
            case .import: self = .importData
            case .export: self = .exportData
            @unknown default: self = .setup
            }
        }
    }

    var onStatusChange: ((CloudSyncStatus) -> Void)?
    private(set) var status: CloudSyncStatus = .checking {
        didSet {
            guard status != oldValue else { return }
            onStatusChange?(status)
        }
    }

    private let persistentContainer: NSPersistentCloudKitContainer?
    private let cloudContainer: CKContainer
    private let notificationCenter: NotificationCenter
    private var eventObserver: NSObjectProtocol?
    private var accountObserver: NSObjectProtocol?
    private var accountTask: Task<Void, Never>?
    private var eventHistoryTask: Task<Void, Never>?
    private var activeEvents: [UUID: Operation] = [:]
    private var accountStatus: CKAccountStatus?
    private var accountErrorMessage: String?
    private var eventHistoryErrorMessage: String?
    private var didLoadEventHistory = false
    private var lastEventFailures: [Operation: (date: Date, message: String)] = [:]
    private var liveEventsDuringHistoryLoad: [UUID: NSPersistentCloudKitContainer.Event] = [:]
    private var isRunning = false

    init(
        persistentContainer: NSPersistentCloudKitContainer?,
        cloudContainer: CKContainer,
        notificationCenter: NotificationCenter = .default
    ) {
        self.persistentContainer = persistentContainer
        self.cloudContainer = cloudContainer
        self.notificationCenter = notificationCenter
    }

    deinit {
        accountTask?.cancel()
        eventHistoryTask?.cancel()
        if let eventObserver {
            notificationCenter.removeObserver(eventObserver)
        }
        if let accountObserver {
            notificationCenter.removeObserver(accountObserver)
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        guard let persistentContainer else {
            status = .unavailable("CloudKit veri deposu etkin değil.")
            return
        }

        eventObserver = notificationCenter.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: persistentContainer,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handle(eventNotification: notification)
            }
        }

        accountObserver = notificationCenter.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAccountStatus()
            }
        }

        status = .checking
        loadEventHistory()
        refreshAccountStatus()
    }

    func refresh() {
        guard isRunning else { return }
        loadEventHistory()
        refreshAccountStatus()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        accountTask?.cancel()
        accountTask = nil
        eventHistoryTask?.cancel()
        eventHistoryTask = nil
        activeEvents.removeAll()
        liveEventsDuringHistoryLoad.removeAll()
        didLoadEventHistory = false

        if let eventObserver {
            notificationCenter.removeObserver(eventObserver)
            self.eventObserver = nil
        }
        if let accountObserver {
            notificationCenter.removeObserver(accountObserver)
            self.accountObserver = nil
        }
    }

    func refreshAccountStatus() {
        guard isRunning, persistentContainer != nil else { return }
        accountTask?.cancel()
        accountTask = Task { [weak self] in
            guard let self else { return }
            do {
                let newStatus = try await cloudContainer.accountStatus()
                guard !Task.isCancelled else { return }
                accountStatus = newStatus
                accountErrorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                accountStatus = nil
                accountErrorMessage = error.localizedDescription
            }
            updateStatus()
        }
    }

    private func handle(eventNotification notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        if !didLoadEventHistory {
            liveEventsDuringHistoryLoad[event.identifier] = event
        }
        apply(event)
        updateStatus()
    }

    private func loadEventHistory() {
        guard let persistentContainer else { return }
        eventHistoryTask?.cancel()
        didLoadEventHistory = false
        eventHistoryErrorMessage = nil
        liveEventsDuringHistoryLoad.removeAll()
        updateStatus()
        eventHistoryTask = Task { [weak self] in
            guard let self else { return }
            do {
                let events = try await fetchRecentEvents(from: persistentContainer)
                guard !Task.isCancelled else { return }
                let liveEvents = liveEventsDuringHistoryLoad.values.sorted {
                    $0.startDate < $1.startDate
                }
                activeEvents.removeAll()
                lastEventFailures.removeAll()
                events.sorted { $0.startDate < $1.startDate }.forEach(apply)
                liveEvents.forEach(apply)
                liveEventsDuringHistoryLoad.removeAll()
                didLoadEventHistory = true
                eventHistoryErrorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                didLoadEventHistory = true
                eventHistoryErrorMessage = error.localizedDescription
            }
            updateStatus()
        }
    }

    private func fetchRecentEvents(
        from container: NSPersistentCloudKitContainer
    ) async throws -> [NSPersistentCloudKitContainer.Event] {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let fetchRequest = NSPersistentCloudKitContainerEventRequest.fetchForEvents()
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "startDate", ascending: false)
                    ]
                    fetchRequest.fetchLimit = 300
                    let request = NSPersistentCloudKitContainerEventRequest.fetchEvents(
                        matchingFetch: fetchRequest
                    )
                    request.resultType = .events
                    let result = try context.execute(request)
                        as? NSPersistentCloudKitContainerEventResult
                    let events = result?.result
                        as? [NSPersistentCloudKitContainer.Event] ?? []
                    continuation.resume(returning: events)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func apply(_ event: NSPersistentCloudKitContainer.Event) {
        let operation = Operation(event.type)
        if event.endDate == nil {
            activeEvents[event.identifier] = operation
        } else {
            activeEvents.removeValue(forKey: event.identifier)
            let completionDate = event.endDate ?? .now
            if event.succeeded {
                if let failure = lastEventFailures[operation],
                   completionDate >= failure.date {
                    lastEventFailures.removeValue(forKey: operation)
                }
            } else {
                lastEventFailures[operation] = (
                    completionDate,
                    event.error?.localizedDescription
                        ?? "iCloud eşitleme işlemi tamamlanamadı."
                )
            }
        }
    }

    private func updateStatus() {
        if let accountErrorMessage {
            status = .unavailable(accountErrorMessage)
            return
        }

        if !activeEvents.isEmpty {
            status = .syncing
            return
        }

        guard let accountStatus, didLoadEventHistory else {
            status = .checking
            return
        }

        switch accountStatus {
        case .available:
            if let eventHistoryErrorMessage {
                status = .unavailable(
                    "iCloud işlem geçmişi okunamadı. \(eventHistoryErrorMessage)"
                )
            } else if let failure = lastEventFailures.values.max(by: {
                $0.date < $1.date
            }) {
                status = .unavailable(failure.message)
            } else {
                status = .current
            }
        case .noAccount:
            status = .unavailable("Bu cihazda etkin bir iCloud hesabı yok.")
        case .restricted:
            status = .unavailable("iCloud erişimi bu cihazda kısıtlanmış.")
        case .temporarilyUnavailable:
            status = .unavailable("iCloud şu anda geçici olarak kullanılamıyor.")
        case .couldNotDetermine:
            status = .unavailable("iCloud hesap durumu belirlenemedi.")
        @unknown default:
            status = .unavailable("iCloud hesap durumu belirlenemedi.")
        }
    }
}
