//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit
import UserNotifications

final class SettingsViewController: UITableViewController {
    var onVehicles: (() -> Void)?
    var onDeleteSelectedVehicle: (() -> Void)?
    private let session: AppSession
    private let notificationService: NotificationSchedulingService
    private var notificationStatus = "Kontrol ediliyor…"

    init(session: AppSession, notificationService: NotificationSchedulingService) {
        self.session = session; self.notificationService = notificationService
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad(); title = nil
        tableView.register(UINib(nibName: "DataListCell", bundle: .main), forCellReuseIdentifier: "DataListCell")
        AppTheme.styleList(tableView)
        tableView.sectionHeaderTopPadding = AppTheme.Spacing.medium
        tableView.tableHeaderView = PageHeaderView(
            title: "Ayarlar",
            message: "Araçlarınızı, bildirim izinlerini ve uygulama bilgilerini yönetin."
        )
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: SettingsViewController, _) in
            controller.tableView.updateTableHeaderHeightIfNeeded()
        }
        Task { await loadNotificationStatus() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.updateTableHeaderHeightIfNeeded()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 4 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 2 : 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Araçlar", "Bildirimler", "Gizlilik", "Hakkında"][section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DataListCell", for: indexPath) as! DataListCell
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.configure(
                title: "Araçları Yönet",
                subtitle: "Garajınızdaki araçları görüntüleyin ve düzenleyin.",
                symbol: "car.2.fill"
            )
        case (0, 1):
            cell.configure(
                title: "Seçili Aracı ve Verilerini Sil",
                subtitle: "Bu işlem geri alınamaz.",
                symbol: "trash.fill",
                tintColor: AppTheme.dangerColor,
                showsDisclosure: false
            )
            cell.selectionStyle = .default
        case (1, _):
            cell.configure(
                title: "Bildirim İzni",
                subtitle: notificationStatus,
                metadata: ["İzni değiştirmek için sistem ayarları açılır."],
                symbol: "bell.fill"
            )
        case (2, _):
            cell.configure(
                title: "Veriler yalnızca bu cihazda saklanır",
                subtitle: "Reklam, hesap veya izleme bulunmaz.",
                symbol: "hand.raised.fill",
                tintColor: AppTheme.successColor,
                showsDisclosure: false
            )
        default:
            cell.configure(
                title: "Project Garage",
                subtitle: "Sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")",
                symbol: "info.circle.fill",
                showsDisclosure: false
            )
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 0 { onVehicles?() }
        if indexPath.section == 0 && indexPath.row == 1 { onDeleteSelectedVehicle?() }
        if indexPath.section == 1 { openSystemSettings() }
    }

    private func loadNotificationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationStatus = switch status {
        case .authorized: "İzin verildi"
        case .denied: "İzin verilmedi"
        case .provisional: "Geçici izin"
        case .ephemeral: "Geçici"
        case .notDetermined: "Henüz istenmedi"
        @unknown default: "Bilinmiyor"
        }
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
