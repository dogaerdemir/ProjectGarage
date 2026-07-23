//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class VehicleListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onAdd: (() -> Void)?
    var onEdit: ((Vehicle) -> Void)?
    var onSelected: ((Vehicle) -> Void)?
    var onDelete: ((Vehicle) -> Void)?
    var onSettings: (() -> Void)?

    private let session: AppSession
    private let repository: VehicleRepository
    private let storage: FileStorageService?
    private var contentView: VehicleListContentView!
    private var vehicles: [Vehicle] = []
    private var reloadTask: Task<Void, Never>?
    private var photoTasks: [UUID: Task<Void, Never>] = [:]
    private var photoCache: [UUID: UIImage] = [:]
    private var cachedPhotoIdentifiers: [UUID: String] = [:]

    init(session: AppSession, repository: VehicleRepository, storage: FileStorageService? = nil) {
        self.session = session
        self.repository = repository
        self.storage = storage
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let rootView = VehicleListContentView.instantiate()
        contentView = rootView
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Araçlarım"
        navigationItem.largeTitleDisplayMode = .never
        configureTableView()
        configureAddButton()

        vehicles = session.vehicles
        updateNavigationMenu()
        updateEmptyState()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectionChanged), name: .selectedVehicleDidChange, object: nil)
        reload()
    }

    deinit {
        reloadTask?.cancel()
        photoTasks.values.forEach { $0.cancel() }
        NotificationCenter.default.removeObserver(self)
    }

    private func configureTableView() {
        contentView.tableView.register(
            UINib(nibName: VehicleCardCell.reuseIdentifier, bundle: .main),
            forCellReuseIdentifier: VehicleCardCell.reuseIdentifier
        )
        contentView.tableView.dataSource = self
        contentView.tableView.delegate = self
        contentView.tableView.backgroundColor = AppTheme.backgroundColor
        contentView.tableView.separatorStyle = .none
        contentView.tableView.rowHeight = UITableView.automaticDimension
        contentView.tableView.estimatedRowHeight = 196
        contentView.tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 8, right: 0)
        contentView.tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 4, left: 0, bottom: 8, right: 0)
    }

    private func configureAddButton() {
        var configuration = AppTheme.primaryButtonConfiguration(title: "Yeni Araç Ekle", symbol: "plus")
        configuration.imagePadding = AppTheme.Spacing.medium
        contentView.addButton.configuration = configuration
        contentView.addButton.accessibilityHint = "Yeni araç formunu açar"
        contentView.addButton.addTarget(self, action: #selector(add), for: .touchUpInside)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { vehicles.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let vehicle = vehicles[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: VehicleCardCell.reuseIdentifier, for: indexPath) as! VehicleCardCell
        cell.configure(
            vehicle: vehicle,
            isSelected: session.selectedVehicle?.id == vehicle.id,
            image: cachedPhoto(for: vehicle)
        )
        loadPhotoIfNeeded(for: vehicle)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vehicle = vehicles[indexPath.row]
        guard !vehicle.isArchived else { return }
        onSelected?(vehicle)
        tableView.reloadData()
        updateNavigationMenu()
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let vehicle = vehicles[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in
            self?.onDelete?(vehicle)
            done(true)
        }
        let edit = UIContextualAction(style: .normal, title: "Düzenle") { [weak self] _, _, done in
            self?.onEdit?(vehicle)
            done(true)
        }
        edit.backgroundColor = AppTheme.accentColor
        let configuration = UISwipeActionsConfiguration(actions: [delete, edit])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func updateNavigationMenu() {
        let selectedID = session.selectedVehicle?.id
        let targetVehicle = vehicles.first(where: { $0.id == selectedID }) ?? vehicles.first(where: { !$0.isArchived }) ?? vehicles.first
        var actions: [UIMenuElement] = []

        if let targetVehicle {
            actions.append(UIAction(title: "Düzenle", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.onEdit?(targetVehicle)
            })
            actions.append(UIAction(title: "Sil", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.onDelete?(targetVehicle)
            })
        } else {
            actions.append(UIAction(title: "Yeni Araç Ekle", image: UIImage(systemName: "plus")) { [weak self] _ in
                self?.onAdd?()
            })
        }
        actions.append(UIAction(title: "Ayarlar", image: UIImage(systemName: "gearshape")) { [weak self] _ in
            self?.onSettings?()
        })

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: UIMenu(children: actions)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Araç işlemleri"
    }

    private func cachedPhoto(for vehicle: Vehicle) -> UIImage? {
        guard let identifier = vehicle.photoIdentifier else {
            clearCachedPhoto(for: vehicle.id)
            return nil
        }
        if let cachedIdentifier = cachedPhotoIdentifiers[vehicle.id], cachedIdentifier != identifier {
            clearCachedPhoto(for: vehicle.id)
        }
        return cachedPhotoIdentifiers[vehicle.id] == identifier ? photoCache[vehicle.id] : nil
    }

    private func loadPhotoIfNeeded(for vehicle: Vehicle) {
        guard
            let storage,
            let identifier = vehicle.photoIdentifier,
            !(cachedPhotoIdentifiers[vehicle.id] == identifier && photoCache[vehicle.id] != nil),
            photoTasks[vehicle.id] == nil
        else { return }

        photoTasks[vehicle.id] = Task { [weak self] in
            do {
                let data = try await storage.read(relativePath: identifier)
                guard !Task.isCancelled, let self else { return }
                photoTasks[vehicle.id] = nil
                guard let image = UIImage(data: data) else { return }
                photoCache[vehicle.id] = image
                cachedPhotoIdentifiers[vehicle.id] = identifier
                guard let row = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
                let indexPath = IndexPath(row: row, section: 0)
                if contentView.tableView.indexPathsForVisibleRows?.contains(indexPath) == true {
                    contentView.tableView.reloadRows(at: [indexPath], with: .none)
                }
            } catch {
                self?.photoTasks[vehicle.id] = nil
            }
        }
    }

    private func clearCachedPhoto(for vehicleID: UUID) {
        photoTasks[vehicleID]?.cancel()
        photoTasks[vehicleID] = nil
        photoCache[vehicleID] = nil
        cachedPhotoIdentifiers[vehicleID] = nil
    }

    @objc private func add() { onAdd?() }

    @objc private func selectionChanged() {
        contentView.tableView.reloadData()
        updateNavigationMenu()
    }

    @objc func reload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            guard let self, let fetched = try? await repository.fetchVehicles(includeArchived: true), !Task.isCancelled else { return }
            let fetchedIDs = Set(fetched.map(\.id))
            photoCache.keys.filter { !fetchedIDs.contains($0) }.forEach(clearCachedPhoto)
            for vehicle in fetched where vehicles.first(where: { $0.id == vehicle.id })?.photoIdentifier != vehicle.photoIdentifier {
                clearCachedPhoto(for: vehicle.id)
            }
            guard fetched != vehicles else {
                updateNavigationMenu()
                updateEmptyState()
                return
            }
            vehicles = fetched
            UIView.performWithoutAnimation {
                self.contentView.tableView.reloadData()
                self.contentView.tableView.layoutIfNeeded()
            }
            updateNavigationMenu()
            updateEmptyState()
        }
    }

    private func updateEmptyState() {
        let emptyState = EmptyStateView(
            symbol: "car.2.fill",
            title: "Henüz araç yok",
            message: "İlk aracınızı ekleyerek garajınızı oluşturmaya başlayın."
        )
        contentView.tableView.showEmptyState(emptyState, when: vehicles.isEmpty)
    }
}
