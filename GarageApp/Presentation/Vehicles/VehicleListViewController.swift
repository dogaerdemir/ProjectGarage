//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class VehicleListViewController: UITableViewController {
    var onAdd: (() -> Void)?
    var onEdit: ((Vehicle) -> Void)?
    var onSelected: ((Vehicle) -> Void)?
    var onDelete: ((Vehicle) -> Void)?
    var onArchive: ((Vehicle) -> Void)?
    private let session: AppSession
    private let repository: VehicleRepository
    private var vehicles: [Vehicle] = []
    private var reloadTask: Task<Void, Never>?

    init(session: AppSession, repository: VehicleRepository) { self.session = session; self.repository = repository; super.init(style: .insetGrouped) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad(); title = nil; navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        tableView.register(UINib(nibName: "DataListCell", bundle: .main), forCellReuseIdentifier: "DataListCell")
        AppTheme.styleList(tableView)
        tableView.sectionHeaderTopPadding = 0
        tableView.tableHeaderView = PageHeaderView(
            title: "Araçlarım",
            message: "Garajınızdaki araçları seçin, düzenleyin veya arşivleyin."
        )
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: VehicleListViewController, _) in
            controller.tableView.updateTableHeaderHeightIfNeeded()
        }
        vehicles = session.vehicles
        updateEmptyState()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        reload()
    }
    deinit {
        reloadTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.updateTableHeaderHeightIfNeeded()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { vehicles.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let vehicle = vehicles[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "DataListCell", for: indexPath) as! DataListCell
        var identityParts = [vehicle.make, vehicle.model].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if let year = vehicle.modelYear { identityParts.append(String(year)) }
        let identity = identityParts.joined(separator: " · ")
        let mileage = AppFormatters.mileage.string(from: NSNumber(value: vehicle.currentMileage)) ?? String(vehicle.currentMileage)
        var metadata = ["Kilometre · \(mileage) km"]
        if let plate = vehicle.plateNumber, !plate.isEmpty { metadata.insert("Plaka · \(plate)", at: 0) }
        if vehicle.isArchived { metadata.append("Durum · Arşivlendi") }
        cell.configure(
            title: vehicle.nickname,
            subtitle: identity.isEmpty ? nil : identity,
            metadata: metadata,
            symbol: "car.fill",
            showsDisclosure: !vehicle.isArchived
        )
        cell.accessoryType = session.selectedVehicle?.id == vehicle.id ? .checkmark : (vehicle.isArchived ? .none : .disclosureIndicator)
        cell.contentView.alpha = vehicle.isArchived ? 0.55 : 1
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { tableView.deselectRow(at: indexPath, animated: true); let vehicle = vehicles[indexPath.row]; if !vehicle.isArchived { onSelected?(vehicle) } }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let vehicle = vehicles[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in self?.onDelete?(vehicle); done(true) }
        let edit = UIContextualAction(style: .normal, title: "Düzenle") { [weak self] _, _, done in self?.onEdit?(vehicle); done(true) }
        let archive = UIContextualAction(style: .normal, title: vehicle.isArchived ? "Geri Al" : "Arşivle") { [weak self] _, _, done in self?.onArchive?(vehicle); done(true) }; archive.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [delete, archive, edit])
    }
    @objc private func add() { onAdd?() }
    @objc func reload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            guard let self else { return }
            let fetched = (try? await repository.fetchVehicles(includeArchived: true)) ?? []
            guard !Task.isCancelled, fetched != self.vehicles else {
                self.updateEmptyState()
                return
            }
            self.vehicles = fetched
            UIView.performWithoutAnimation {
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
            }
            self.updateEmptyState()
        }
    }
    private func updateEmptyState() {
        let emptyState = EmptyStateView(symbol: "car.2.fill", title: "Henüz araç yok", message: "İlk aracınızı ekleyerek garajınızı oluşturmaya başlayın.", actionTitle: "Araç Ekle") { [weak self] in self?.onAdd?() }
        tableView.showEmptyState(emptyState, when: vehicles.isEmpty)
    }
}
