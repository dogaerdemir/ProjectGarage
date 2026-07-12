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

    init(session: AppSession, repository: VehicleRepository) { self.session = session; self.repository = repository; super.init(style: .insetGrouped) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad(); title = "Araçlarım"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Vehicle")
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        reload()
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { vehicles.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let vehicle = vehicles[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Vehicle", for: indexPath)
        var content = cell.defaultContentConfiguration(); content.text = vehicle.nickname
        content.secondaryText = "\(vehicle.make) \(vehicle.model) • \(vehicle.currentMileage) km" + (vehicle.isArchived ? " • Arşivlendi" : "")
        content.image = UIImage(systemName: "car.fill"); cell.contentConfiguration = content
        cell.accessoryType = session.selectedVehicle?.id == vehicle.id ? .checkmark : (vehicle.isArchived ? .none : .disclosureIndicator)
        cell.contentView.alpha = vehicle.isArchived ? 0.55 : 1
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { let vehicle = vehicles[indexPath.row]; if !vehicle.isArchived { onSelected?(vehicle) } }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let vehicle = vehicles[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in self?.onDelete?(vehicle); done(true) }
        let edit = UIContextualAction(style: .normal, title: "Düzenle") { [weak self] _, _, done in self?.onEdit?(vehicle); done(true) }
        let archive = UIContextualAction(style: .normal, title: vehicle.isArchived ? "Geri Al" : "Arşivle") { [weak self] _, _, done in self?.onArchive?(vehicle); done(true) }; archive.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [delete, archive, edit])
    }
    @objc private func add() { onAdd?() }
    @objc func reload() { Task { vehicles = (try? await repository.fetchVehicles(includeArchived: true)) ?? []; tableView.reloadData() } }
}
