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
        super.viewDidLoad(); title = "Ayarlar"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Setting")
        Task { await loadNotificationStatus() }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 4 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 2 : 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Araçlar", "Bildirimler", "Gizlilik", "Hakkında"][section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Setting", for: indexPath)
        var content = cell.defaultContentConfiguration(); cell.accessoryType = .none
        switch (indexPath.section, indexPath.row) {
        case (0, 0): content.text = "Araçları Yönet"; content.image = UIImage(systemName: "car.2.fill"); cell.accessoryType = .disclosureIndicator
        case (0, 1): content.text = "Seçili Aracı ve Verilerini Sil"; content.image = UIImage(systemName: "trash"); content.textProperties.color = UIColor(named: "Danger") ?? .systemRed
        case (1, _): content.text = "Bildirim İzni"; content.secondaryText = notificationStatus; content.image = UIImage(systemName: "bell.fill")
        case (2, _): content.text = "Veriler yalnızca bu cihazda saklanır"; content.secondaryText = "Reklam, hesap veya izleme bulunmaz."; content.image = UIImage(systemName: "hand.raised.fill")
        default:
            content.text = "Project Garage"
            content.secondaryText = "Sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
            content.image = UIImage(systemName: "info.circle.fill")
        }
        cell.contentConfiguration = content; return cell
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
