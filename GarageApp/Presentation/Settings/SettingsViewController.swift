//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit
import UserNotifications

final class SettingsViewController: UITableViewController {
    var onVehicles: (() -> Void)?
    var onCloudSync: (() -> Void)?
    private let cloudSyncController: CloudSyncController
    private var notificationStatus = "Kontrol ediliyor…"

    private enum Section: Int, CaseIterable {
        case vehicle
        case appearance
        case notifications
        case dataAndPrivacy
        case about

        var title: String {
            switch self {
            case .vehicle: "ARAÇ"
            case .appearance: "GÖRÜNÜM"
            case .notifications: "BİLDİRİMLER"
            case .dataAndPrivacy: "VERİLER VE GİZLİLİK"
            case .about: "HAKKINDA"
            }
        }

        var items: [Item] {
            switch self {
            case .vehicle: [.vehicles]
            case .appearance: [.appearanceLight, .appearanceDark, .appearanceSystem]
            case .notifications: [.notificationPermission]
            case .dataAndPrivacy: [.cloudSync]
            case .about: [.version]
            }
        }
    }

    private enum Item {
        case vehicles
        case appearanceLight
        case appearanceDark
        case appearanceSystem
        case notificationPermission
        case cloudSync
        case version

        var appearanceMode: AppAppearanceMode? {
            switch self {
            case .appearanceLight: .light
            case .appearanceDark: .dark
            case .appearanceSystem: .system
            default: nil
            }
        }
    }

    init(cloudSyncController: CloudSyncController) {
        self.cloudSyncController = cloudSyncController
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Setting")
        AppTheme.styleList(tableView)
        tableView.estimatedRowHeight = 56
        tableView.rowHeight = 56
        tableView.sectionHeaderTopPadding = 0
        configurePageHeader()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudSyncStatusDidChange),
            name: .cloudSyncStatusDidChange,
            object: cloudSyncController
        )
        cloudSyncController.refresh()
        Task { await loadNotificationStatus() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.updateTableHeaderHeightIfNeeded()
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

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 42 : 44
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Setting", for: indexPath)
        guard let item = item(at: indexPath) else { return cell }

        var content = item == .notificationPermission || item == .cloudSync
            ? UIListContentConfiguration.valueCell()
            : cell.defaultContentConfiguration()
        cell.accessoryType = .none
        cell.selectionStyle = .none
        content.textProperties.font = AppTheme.font(.body)
        content.textProperties.color = AppTheme.primaryTextColor
        content.secondaryTextProperties.font = AppTheme.font(.body)
        content.secondaryTextProperties.color = AppTheme.secondaryTextColor
        content.imageProperties.tintColor = AppTheme.secondaryTextColor

        switch item {
        case .vehicles:
            content.text = "Araçlarım"
            content.image = UIImage(systemName: "car")
            cell.accessoryType = .disclosureIndicator
        case .appearanceLight, .appearanceDark, .appearanceSystem:
            guard let mode = item.appearanceMode else { break }
            content.text = mode.title
            content.image = UIImage(systemName: mode.symbolName)
            cell.accessoryType = AppAppearanceController.shared.mode == mode ? .checkmark : .none
        case .notificationPermission:
            content.text = "Bildirim İzni"
            content.secondaryText = notificationStatus
            content.image = UIImage(systemName: "bell")
            cell.accessoryType = .disclosureIndicator
        case .cloudSync:
            content.text = "iCloud Eşitleme"
            content.secondaryText = cloudSyncController.status.title
            content.image = UIImage(systemName: cloudSyncController.status.symbolName)
            cell.accessoryType = .disclosureIndicator
        case .version:
            content.text = versionText
        }
        content.updateImageLayout(
            reservedSize: CGSize(width: 24, height: 24),
            textPadding: AppTheme.Spacing.medium
        )
        cell.contentConfiguration = content
        cell.isUserInteractionEnabled = item != .version
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = content.text
        cell.accessibilityValue = content.secondaryText
        cell.accessibilityTraits = item == .version ? .staticText : .button
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = item(at: indexPath) else { return }
        switch item {
        case .vehicles: onVehicles?()
        case .appearanceLight, .appearanceDark, .appearanceSystem:
            guard let mode = item.appearanceMode else { return }
            AppAppearanceController.shared.update(mode)
            tableView.reloadSections(IndexSet(integer: Section.appearance.rawValue), with: .none)
        case .notificationPermission: openSystemSettings()
        case .cloudSync: onCloudSync?()
        case .version: break
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

    private func configurePageHeader() {
        let header = UIView()
        header.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = "Ayarlar"
        AppTheme.stylePageTitle(titleLabel)
        header.addSubview(titleLabel)
        titleLabel.pinToEdges(
            of: header,
            insets: NSDirectionalEdgeInsets(
                top: AppTheme.Metrics.pageTopInset,
                leading: AppTheme.Metrics.horizontalMargin,
                bottom: AppTheme.Metrics.pageTitleToContentSpacing,
                trailing: AppTheme.Metrics.horizontalMargin
            )
        )

        header.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 50)
        tableView.tableHeaderView = header
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
        cloudSyncController.refresh()
        Task { await loadNotificationStatus() }
    }

    @objc private func cloudSyncStatusDidChange() {
        tableView.reloadSections(IndexSet(integer: Section.dataAndPrivacy.rawValue), with: .none)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
