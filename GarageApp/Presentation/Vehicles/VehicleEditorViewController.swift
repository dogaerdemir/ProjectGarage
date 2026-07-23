//
//  Created by Doğa Erdemir on 12.07.2026.
//

import PhotosUI
import UIKit

final class VehicleEditorViewController: UITableViewController, PHPickerViewControllerDelegate {
    var onSaved: ((Vehicle) -> Void)?

    private enum Section: Int, CaseIterable { case photo, fields }
    private enum Row: Int, CaseIterable { case nickname, make, model, year, fuel, transmission, mileage, plate, vin }

    private let repository: VehicleRepository
    private let storage: FileStorageService
    private var vehicle: Vehicle?
    private var nickname = "", make = "", model = "", plate = "", vin = ""
    private var modelYear: Int?, mileage: Int64 = 0
    private var fuelType: FuelType?, transmission: TransmissionType?
    private var pendingPhotoData: Data?
    private var pendingPhotoImage: UIImage?
    private var existingPhotoImage: UIImage?
    private var photoLoadTask: Task<Void, Never>?

    init(vehicle: Vehicle?, repository: VehicleRepository, storage: FileStorageService) {
        self.vehicle = vehicle
        self.repository = repository
        self.storage = storage
        super.init(style: .insetGrouped)
        if let vehicle {
            nickname = vehicle.nickname
            make = vehicle.make
            model = vehicle.model
            modelYear = vehicle.modelYear
            fuelType = vehicle.fuelType
            transmission = vehicle.transmissionType
            plate = vehicle.plateNumber ?? ""
            vin = vehicle.vin ?? ""
            mileage = vehicle.currentMileage
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = vehicle == nil ? "Araç Ekle" : "Aracı Düzenle"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Vazgeç", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kaydet", style: .done, target: self, action: #selector(save))
        configureTableView()
        updateSaveButtonState()
        loadExistingPhoto()
    }

    deinit { photoLoadTask?.cancel() }

    private func configureTableView() {
        tableView.register(
            UINib(nibName: VehicleEditorPhotoCell.reuseIdentifier, bundle: .main),
            forCellReuseIdentifier: VehicleEditorPhotoCell.reuseIdentifier
        )
        tableView.register(
            UINib(nibName: VehicleEditorFieldCell.reuseIdentifier, bundle: .main),
            forCellReuseIdentifier: VehicleEditorFieldCell.reuseIdentifier
        )
        tableView.backgroundColor = AppTheme.backgroundColor
        tableView.separatorColor = AppTheme.borderColor
        tableView.separatorInset = UIEdgeInsets(top: 0, left: AppTheme.Spacing.medium, bottom: 0, right: AppTheme.Spacing.medium)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.sectionHeaderTopPadding = 0
        tableView.keyboardDismissMode = .onDrag
        tableView.cellLayoutMarginsFollowReadableWidth = false
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .photo ? 1 : Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == Section.photo.rawValue ? 168 : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == Section.photo.rawValue ? AppTheme.Spacing.medium : AppTheme.Spacing.standard
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == Section.photo.rawValue {
            cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        } else {
            cell.separatorInset = UIEdgeInsets(top: 0, left: AppTheme.Spacing.medium, bottom: 0, right: AppTheme.Spacing.medium)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Section.photo.rawValue {
            let cell = tableView.dequeueReusableCell(withIdentifier: VehicleEditorPhotoCell.reuseIdentifier, for: indexPath) as! VehicleEditorPhotoCell
            cell.configure(image: pendingPhotoImage ?? existingPhotoImage)
            return cell
        }

        guard let row = Row(rawValue: indexPath.row) else { return UITableViewCell() }
        let cell = tableView.dequeueReusableCell(withIdentifier: VehicleEditorFieldCell.reuseIdentifier, for: indexPath) as! VehicleEditorFieldCell
        configure(cell, for: row)
        return cell
    }

    private func configure(_ cell: VehicleEditorFieldCell, for row: Row) {
        switch row {
        case .nickname:
            cell.configureText(title: "Araç Adı", value: nickname, placeholder: "Örn. Günlük Aracım", autocapitalizationType: .sentences) { [weak self] value in
                self?.nickname = value
                self?.updateSaveButtonState()
            }
        case .make:
            cell.configureText(title: "Marka", value: make, placeholder: "Örn. Opel", autocapitalizationType: .words) { [weak self] in
                self?.make = $0
            }
        case .model:
            cell.configureText(title: "Model", value: model, placeholder: "Örn. Astra", autocapitalizationType: .words) { [weak self] in
                self?.model = $0
            }
        case .year:
            cell.configureText(title: "Yıl", value: modelYear.map(String.init) ?? "", placeholder: "Örn. 2024", keyboardType: .numberPad) { [weak self] in
                self?.modelYear = Int($0)
            }
        case .fuel:
            cell.configureSelection(title: "Yakıt Türü", value: fuelType?.displayName)
        case .transmission:
            cell.configureSelection(title: "Şanzıman", value: transmission?.displayName)
        case .mileage:
            let value = vehicle == nil && mileage == 0 ? "" : String(mileage)
            cell.configureText(title: "Kilometre", value: value, placeholder: "Örn. 0", keyboardType: .numberPad) { [weak self] in
                self?.mileage = Int64($0) ?? 0
            }
        case .plate:
            cell.configureText(title: "Plaka", value: plate, placeholder: "Örn. 06 DGA 2024", autocapitalizationType: .allCharacters) { [weak self] in
                self?.plate = $0.uppercased(with: Locale(identifier: "tr_TR"))
            }
        case .vin:
            cell.configureText(title: "Şasi Numarası", value: vin, placeholder: "Örn. VF7...", keyboardType: .asciiCapable, autocapitalizationType: .allCharacters) { [weak self] in
                self?.vin = $0.uppercased()
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == Section.photo.rawValue {
            selectPhoto()
            return
        }
        guard let row = Row(rawValue: indexPath.row) else { return }
        if row == .fuel { presentFuelChoices() }
        if row == .transmission { presentTransmissionChoices() }
    }

    private func presentFuelChoices() {
        let values = FuelType.allCases
        presentSelectionSheet(
            title: "Yakıt Türü",
            options: values.map { SelectionSheetOption(title: $0.displayName, symbolName: $0.symbolName) },
            selectedIndex: fuelType.flatMap(values.firstIndex)
        ) { [weak self] index in
            guard values.indices.contains(index), let self else { return }
            fuelType = values[index]
            tableView.reloadRows(at: [IndexPath(row: Row.fuel.rawValue, section: Section.fields.rawValue)], with: .none)
        }
    }

    private func presentTransmissionChoices() {
        let values = TransmissionType.allCases
        presentSelectionSheet(
            title: "Şanzıman",
            options: values.map { SelectionSheetOption(title: $0.displayName, symbolName: $0.symbolName) },
            selectedIndex: transmission.flatMap(values.firstIndex)
        ) { [weak self] index in
            guard values.indices.contains(index), let self else { return }
            transmission = values[index]
            tableView.reloadRows(at: [IndexPath(row: Row.transmission.rawValue, section: Section.fields.rawValue)], with: .none)
        }
    }

    private func loadExistingPhoto() {
        guard let identifier = vehicle?.photoIdentifier else { return }
        photoLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await storage.read(relativePath: identifier)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                existingPhotoImage = image
                tableView.reloadRows(at: [IndexPath(row: 0, section: Section.photo.rawValue)], with: .none)
            } catch {
                return
            }
        }
    }

    @objc private func selectPhoto() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.82) else { return }
            DispatchQueue.main.async {
                self?.pendingPhotoData = data
                self?.pendingPhotoImage = image
                self?.tableView.reloadRows(at: [IndexPath(row: 0, section: Section.photo.rawValue)], with: .none)
            }
        }
    }

    private func updateSaveButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @objc private func save() {
        view.endEditing(true)
        let now = Date.now
        var result = vehicle ?? Vehicle(nickname: nickname, make: make, model: model)
        result.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        result.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
        result.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        result.modelYear = modelYear
        result.fuelType = fuelType
        result.transmissionType = transmission
        let normalizedPlate = plate.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedVIN = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        result.plateNumber = normalizedPlate.isEmpty ? nil : normalizedPlate
        result.vin = normalizedVIN.isEmpty ? nil : normalizedVIN
        result.currentMileage = mileage
        result.updatedAt = now
        navigationItem.rightBarButtonItem?.isEnabled = false

        Task {
            do {
                if let pendingPhotoData {
                    let oldPath = result.photoIdentifier
                    result.photoIdentifier = try await storage.save(data: pendingPhotoData, vehicleID: result.id, fileExtension: "jpg")
                    if let oldPath { try? await storage.delete(relativePath: oldPath) }
                }
                if vehicle == nil {
                    try await CreateVehicleUseCase(repository: repository).execute(result)
                } else {
                    try await UpdateVehicleUseCase(repository: repository).execute(result)
                }
                onSaved?(result)
            } catch {
                updateSaveButtonState()
                presentError(error)
            }
        }
    }

    @objc private func cancel() { dismiss(animated: true) }
}

private extension FuelType {
    var displayName: String {
        switch self { case .gasoline: "Benzin"; case .diesel: "Dizel"; case .lpg: "LPG"; case .hybrid: "Hibrit"; case .electric: "Elektrik"; case .other: "Diğer" }
    }

    var symbolName: String {
        switch self { case .gasoline, .diesel, .lpg: "fuelpump.fill"; case .hybrid: "leaf.fill"; case .electric: "bolt.car.fill"; case .other: "ellipsis.circle.fill" }
    }
}

private extension TransmissionType {
    var displayName: String {
        switch self { case .manual: "Manuel"; case .automatic: "Otomatik"; case .semiAutomatic: "Yarı otomatik"; case .other: "Diğer" }
    }

    var symbolName: String {
        switch self { case .manual: "gearshift.layout.sixspeed"; case .automatic: "a.circle.fill"; case .semiAutomatic: "arrow.triangle.2.circlepath"; case .other: "ellipsis.circle.fill" }
    }
}
