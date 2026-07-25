//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CloudKit
import CoreData
import Foundation

enum CloudSyncStatus: Equatable, Sendable {
    case disabled
    case preparingAssets
    case checking
    case current
    case syncing
    case unavailable(String)
    case restartRequired

    var title: String {
        switch self {
        case .disabled: "Kapalı"
        case .preparingAssets: "Dosyalar hazırlanıyor"
        case .checking: "Kontrol ediliyor…"
        case .current: "Güncel"
        case .syncing: "Eşitleniyor"
        case .unavailable: "iCloud kullanılamıyor"
        case .restartRequired: "Yeniden başlatma gerekli"
        }
    }

    var detail: String {
        switch self {
        case .disabled:
            "Veriler yalnızca bu cihazda saklanıyor."
        case .preparingAssets:
            "Mevcut fotoğraf ve belgeler güvenli eşitleme için hazırlanıyor."
        case .checking:
            "iCloud hesabı ve eşitleme durumu kontrol ediliyor."
        case .current:
            "Bekleyen bir iCloud işlemi görünmüyor."
        case .syncing:
            "Değişiklikler iCloud ile eşitleniyor."
        case .unavailable(let message):
            message
        case .restartRequired:
            "Seçiminiz uygulama yeniden açıldığında uygulanacak."
        }
    }

    var symbolName: String {
        switch self {
        case .disabled: "icloud.slash"
        case .preparingAssets: "externaldrive.badge.icloud"
        case .checking: "icloud"
        case .current: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .unavailable: "exclamationmark.icloud"
        case .restartRequired: "arrow.clockwise.circle"
        }
    }
}

extension Notification.Name {
    static let cloudSyncStatusDidChange = Notification.Name("cloudSyncStatusDidChange")
}

@MainActor
final class CloudSyncController {
    static let preferenceKey = "cloudSyncEnabled"
    private static let assetMigrationVersion = 2
    private static let assetMigrationVersionKey = "cloudAssetMigrationVersion"

    private enum AssetPreparationState: Equatable {
        case pending
        case running
        case ready
        case failed(String)
    }

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let activeConfigurationIsCloudEnabled: Bool
    private let startupErrorMessage: String?
    private let monitor: CloudSyncMonitor
    private let legacyAssetMigrator: LegacyAssetMigrator
    private let requiresLegacyAssetPreparation: Bool
    private var assetPreparationState: AssetPreparationState

    private(set) var status: CloudSyncStatus = .disabled {
        didSet {
            guard status != oldValue else { return }
            notificationCenter.post(name: .cloudSyncStatusDidChange, object: self)
        }
    }

    var isEnabled: Bool {
        Self.preferredCloudSyncEnabled(defaults: defaults)
    }

    var isAssetPreparationReady: Bool {
        assetPreparationState == .ready
    }

    init(
        persistentContainer: NSPersistentContainer,
        cloudContainerIdentifier: String,
        activeConfigurationIsCloudEnabled: Bool,
        legacyAssetMigrator: LegacyAssetMigrator,
        requiresLegacyAssetPreparation: Bool = true,
        startupError: Error? = nil,
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.activeConfigurationIsCloudEnabled = activeConfigurationIsCloudEnabled
        self.legacyAssetMigrator = legacyAssetMigrator
        self.requiresLegacyAssetPreparation = requiresLegacyAssetPreparation
        startupErrorMessage = startupError?.localizedDescription
        assetPreparationState = !requiresLegacyAssetPreparation
            || Self.legacyAssetsArePrepared(defaults: defaults)
            ? .ready
            : .pending
        monitor = CloudSyncMonitor(
            persistentContainer: persistentContainer as? NSPersistentCloudKitContainer,
            cloudContainer: CKContainer(identifier: cloudContainerIdentifier),
            notificationCenter: notificationCenter
        )

        monitor.onStatusChange = { [weak self] monitorStatus in
            guard let self,
                  isEnabled,
                  activeConfigurationIsCloudEnabled
            else {
                return
            }
            status = monitorStatus
        }
        applyPreferredMode()
    }

    static func preferredCloudSyncEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: preferenceKey)
    }

    static func legacyAssetsArePrepared(defaults: UserDefaults = .standard) -> Bool {
        defaults.integer(forKey: assetMigrationVersionKey) >= assetMigrationVersion
    }

    @discardableResult
    func setEnabled(_ isEnabled: Bool) -> Bool {
        if isEnabled, !isAssetPreparationReady {
            applyPreferredMode()
            return false
        }
        guard isEnabled != self.isEnabled else { return true }
        defaults.set(isEnabled, forKey: Self.preferenceKey)
        applyPreferredMode()
        return true
    }

    func prepareLegacyAssets() async {
        guard requiresLegacyAssetPreparation else {
            assetPreparationState = .ready
            applyPreferredMode()
            return
        }
        guard assetPreparationState != .running else { return }
        if Self.legacyAssetsArePrepared(defaults: defaults) {
            assetPreparationState = .ready
            applyPreferredMode()
            return
        }

        assetPreparationState = .running
        applyPreferredMode()
        do {
            let report = try await legacyAssetMigrator.mirrorLegacyFiles()
            if report.isComplete {
                defaults.set(
                    Self.assetMigrationVersion,
                    forKey: Self.assetMigrationVersionKey
                )
                assetPreparationState = .ready
            } else {
                assetPreparationState = .failed(
                    "\(report.failedRelativePaths.count) fotoğraf veya belge hazırlanamadı. Dosyaları kontrol edip yeniden deneyin."
                )
            }
        } catch {
            assetPreparationState = .failed(
                "Fotoğraf ve belgeler hazırlanamadı. \(error.localizedDescription)"
            )
        }
        applyPreferredMode()
    }

    func refresh() {
        applyPreferredMode()
        if isEnabled, activeConfigurationIsCloudEnabled {
            monitor.refresh()
        }
    }

    private func applyPreferredMode() {
        switch assetPreparationState {
        case .pending, .running:
            monitor.stop()
            status = .preparingAssets
            return
        case .failed(let message):
            monitor.stop()
            status = .unavailable(message)
            return
        case .ready:
            break
        }

        guard isEnabled == activeConfigurationIsCloudEnabled else {
            monitor.stop()
            if isEnabled, let startupErrorMessage {
                status = .unavailable(
                    "iCloud başlatılamadı; uygulama yerel olarak çalışıyor. \(startupErrorMessage)"
                )
            } else {
                status = .restartRequired
            }
            return
        }

        guard isEnabled else {
            monitor.stop()
            status = .disabled
            return
        }

        monitor.start()
        status = monitor.status
    }
}
