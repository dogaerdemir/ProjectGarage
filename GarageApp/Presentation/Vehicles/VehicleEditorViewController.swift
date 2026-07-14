//
//  Created by Doğa Erdemir on 12.07.2026.
//

import PhotosUI
import UIKit

final class VehicleEditorViewController: UITableViewController, PHPickerViewControllerDelegate {
    var onSaved: ((Vehicle) -> Void)?
    private let repository: VehicleRepository
    private let storage: FileStorageService
    private var vehicle: Vehicle?
    private var nickname = "", make = "", model = "", plate = "", vin = ""
    private var modelYear: Int?, mileage: Int64 = 0
    private var fuelType: FuelType?, transmission: TransmissionType?
    private var pendingPhotoData: Data?

    private enum Row { case nickname, make, model, year, fuel, transmission, mileage, plate, vin, photo }

    private enum Section: Int, CaseIterable {
        case basics, specifications, identity, photo

        var title: String {
            switch self {
            case .basics: "Temel Bilgiler"
            case .specifications: "Teknik Bilgiler"
            case .identity: "Araç Kimliği"
            case .photo: "Fotoğraf"
            }
        }

        var footer: String? {
            switch self {
            case .basics: "Araç adı zorunludur. Diğer bilgileri daha sonra tamamlayabilirsiniz."
            case .identity: "Plaka ve şasi numarası isteğe bağlıdır ve yalnızca cihazınızda saklanır."
            case .specifications, .photo: nil
            }
        }

        var rows: [Row] {
            switch self {
            case .basics: [.nickname, .make, .model, .year]
            case .specifications: [.fuel, .transmission, .mileage]
            case .identity: [.plate, .vin]
            case .photo: [.photo]
            }
        }
    }

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
        registerCells()
        AppTheme.styleForm(tableView)
        updateSaveButtonState()
    }

    private func registerCells() {
        ["TextInputCell", "DecimalInputCell", "SelectionCell", "AttachmentPickerCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: .main), forCellReuseIdentifier: $0)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section)?.rows.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Section(rawValue: section)?.footer
    }

    private func row(at indexPath: IndexPath) -> Row? {
        guard let section = Section(rawValue: indexPath.section), section.rows.indices.contains(indexPath.row) else { return nil }
        return section.rows[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = row(at: indexPath) else { return UITableViewCell() }
        switch row {
        case .nickname, .make, .model, .plate, .vin:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextInputCell", for: indexPath) as! TextInputCell
            switch row {
            case .nickname:
                cell.configure(title: "Araç adı", value: nickname, placeholder: "Örn. Aile arabası", autocapitalizationType: .sentences) { [weak self] value in
                    self?.nickname = value
                    self?.updateSaveButtonState()
                }
            case .make:
                cell.configure(title: "Marka", value: make, placeholder: "Örn. Toyota", autocapitalizationType: .words) { [weak self] in self?.make = $0 }
            case .model:
                cell.configure(title: "Model", value: model, placeholder: "Örn. Corolla", autocapitalizationType: .words) { [weak self] in self?.model = $0 }
            case .plate:
                cell.configure(title: "Plaka · isteğe bağlı", value: plate, placeholder: "34 ABC 123", autocapitalizationType: .allCharacters) { [weak self] in
                    self?.plate = $0.uppercased(with: Locale(identifier: "tr_TR"))
                }
            case .vin:
                cell.configure(title: "Şasi numarası · isteğe bağlı", value: vin, placeholder: "17 haneli şasi numarası", keyboardType: .asciiCapable, autocapitalizationType: .allCharacters) { [weak self] in
                    self?.vin = $0.uppercased()
                }
            default: break
            }
            return cell

        case .year, .mileage:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DecimalInputCell", for: indexPath) as! DecimalInputCell
            if row == .year {
                cell.configure(title: "Model yılı", value: modelYear.map(String.init) ?? "", placeholder: "Örn. 2022", keyboardType: .numberPad) { [weak self] in
                    self?.modelYear = Int($0)
                }
            } else {
                cell.configure(title: "Güncel kilometre", value: String(mileage), placeholder: "0", keyboardType: .numberPad, suffix: "km") { [weak self] in
                    self?.mileage = Int64($0) ?? 0
                }
            }
            return cell

        case .fuel, .transmission:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectionCell", for: indexPath) as! SelectionCell
            if row == .fuel {
                cell.configure(title: "Yakıt türü", value: fuelType?.displayName)
            } else {
                cell.configure(title: "Şanzıman", value: transmission?.displayName)
            }
            return cell

        case .photo:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AttachmentPickerCell", for: indexPath) as! AttachmentPickerCell
            let hasPhoto = pendingPhotoData != nil || vehicle?.photoIdentifier != nil
            cell.configure(
                title: "Araç fotoğrafı · isteğe bağlı",
                actionTitle: hasPhoto ? "Fotoğrafı Değiştir" : "Fotoğraf Seç",
                symbol: hasPhoto ? "photo.fill" : "photo.badge.plus"
            ) { [weak self] in self?.selectPhoto() }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = row(at: indexPath) else { return }
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
            guard values.indices.contains(index) else { return }
            self?.fuelType = values[index]
            self?.tableView.reloadSections(IndexSet(integer: Section.specifications.rawValue), with: .automatic)
        }
    }

    private func presentTransmissionChoices() {
        let values = TransmissionType.allCases
        presentSelectionSheet(
            title: "Şanzıman",
            options: values.map { SelectionSheetOption(title: $0.displayName, symbolName: $0.symbolName) },
            selectedIndex: transmission.flatMap(values.firstIndex)
        ) { [weak self] index in
            guard values.indices.contains(index) else { return }
            self?.transmission = values[index]
            self?.tableView.reloadSections(IndexSet(integer: Section.specifications.rawValue), with: .automatic)
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
            guard let data = (object as? UIImage)?.jpegData(compressionQuality: 0.82) else { return }
            DispatchQueue.main.async {
                self?.pendingPhotoData = data
                self?.tableView.reloadSections(IndexSet(integer: Section.photo.rawValue), with: .automatic)
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
                if vehicle == nil { try await CreateVehicleUseCase(repository: repository).execute(result) }
                else { try await UpdateVehicleUseCase(repository: repository).execute(result) }
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
