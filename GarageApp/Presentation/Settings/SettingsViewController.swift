//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit
import UserNotifications

final class SettingsViewController: UITableViewController {
    var onVehicles: (() -> Void)?
    var onReminders: (() -> Void)?
    var onPrivacy: (() -> Void)?
    var onAbout: (() -> Void)?
    var onDeleteSelectedVehicle: (() -> Void)?
    private let session: AppSession
    private let notificationService: NotificationSchedulingService
    private var notificationStatus = "Kontrol ediliyor…"

    private enum Section: Int, CaseIterable {
        case vehicle
        case notifications
        case dataAndPrivacy
        case about

        var title: String {
            switch self {
            case .vehicle: "ARAÇ"
            case .notifications: "BİLDİRİMLER"
            case .dataAndPrivacy: "VERİLER VE GİZLİLİK"
            case .about: "HAKKINDA"
            }
        }

        var items: [Item] {
            switch self {
            case .vehicle: [.vehicles, .reminders]
            case .notifications: [.notificationPermission]
            case .dataAndPrivacy: [.privacy, .deleteSelectedVehicle]
            case .about: [.projectGarage, .version]
            }
        }
    }

    private enum Item {
        case vehicles
        case reminders
        case notificationPermission
        case privacy
        case deleteSelectedVehicle
        case projectGarage
        case version
    }

    init(session: AppSession, notificationService: NotificationSchedulingService) {
        self.session = session; self.notificationService = notificationService
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad(); title = "Ayarlar"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Setting")
        AppTheme.styleList(tableView)
        tableView.estimatedRowHeight = 56
        tableView.rowHeight = 56
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        Task { await loadNotificationStatus() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sectionModel(at: section)?.items.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sectionModel(at: section)?.title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Setting", for: indexPath)
        guard let item = item(at: indexPath) else { return cell }

        var content = item == .notificationPermission
            ? UIListContentConfiguration.valueCell()
            : cell.defaultContentConfiguration()
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        content.textProperties.font = AppTheme.font(.body)
        content.textProperties.color = AppTheme.primaryTextColor
        content.secondaryTextProperties.font = AppTheme.font(.body)
        content.secondaryTextProperties.color = AppTheme.secondaryTextColor
        content.imageProperties.tintColor = AppTheme.secondaryTextColor
        content.imageProperties.reservedLayoutSize = CGSize(width: 24, height: 24)
        content.imageToTextPadding = AppTheme.Spacing.medium

        switch item {
        case .vehicles:
            content.text = "Araçlarım"
            content.image = UIImage(systemName: "car")
        case .reminders:
            content.text = "Hatırlatmalar"
            content.image = UIImage(systemName: "bell")
        case .notificationPermission:
            content.text = "Bildirim İzni"
            content.secondaryText = notificationStatus
            content.image = UIImage(systemName: "bell")
        case .privacy:
            content.text = "Gizlilik"
            content.image = UIImage(systemName: "checkmark.shield")
        case .deleteSelectedVehicle:
            content.text = "Seçili Aracın Verilerini Sil"
            content.image = UIImage(systemName: "trash")
            content.textProperties.color = AppTheme.dangerColor
            content.imageProperties.tintColor = AppTheme.dangerColor
        case .projectGarage:
            content.text = "Project Garage"
            content.image = UIImage(systemName: "info.circle")
        case .version:
            content.text = versionText
            content.image = UIImage(systemName: "circle")
            content.imageProperties.tintColor = .clear
        }
        cell.contentConfiguration = content
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = content.text
        cell.accessibilityValue = content.secondaryText
        cell.accessibilityTraits = .button
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = item(at: indexPath) else { return }
        switch item {
        case .vehicles: onVehicles?()
        case .reminders: onReminders?()
        case .notificationPermission: openSystemSettings()
        case .privacy: onPrivacy?()
        case .deleteSelectedVehicle: onDeleteSelectedVehicle?()
        case .projectGarage, .version: onAbout?()
        }
    }

    private func loadNotificationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationStatus = switch status {
        case .authorized, .provisional, .ephemeral: "Açık"
        case .denied, .notDetermined: "Kapalı"
        @unknown default: "Bilinmiyor"
        }
        tableView.reloadSections(IndexSet(integer: Section.notifications.rawValue), with: .none)
    }

    private var versionText: String {
        let rawVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        var components = rawVersion.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        while components.count < 3 { components.append("0") }
        return "Sürüm \(components.joined(separator: "."))"
    }

    private func sectionModel(at index: Int) -> Section? {
        Section(rawValue: index)
    }

    private func item(at indexPath: IndexPath) -> Item? {
        guard let section = sectionModel(at: indexPath.section), section.items.indices.contains(indexPath.row) else {
            return nil
        }
        return section.items[indexPath.row]
    }

    @objc private func applicationDidBecomeActive() {
        Task { await loadNotificationStatus() }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
