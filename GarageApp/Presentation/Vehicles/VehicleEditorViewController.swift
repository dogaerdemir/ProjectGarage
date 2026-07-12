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

    private enum Row: Int, CaseIterable { case nickname, make, model, year, fuel, transmission, plate, vin, mileage, photo }

    init(vehicle: Vehicle?, repository: VehicleRepository, storage: FileStorageService) {
        self.vehicle = vehicle; self.repository = repository; self.storage = storage
        super.init(style: .insetGrouped)
        if let vehicle {
            nickname = vehicle.nickname; make = vehicle.make; model = vehicle.model
            modelYear = vehicle.modelYear; fuelType = vehicle.fuelType; transmission = vehicle.transmissionType
            plate = vehicle.plateNumber ?? ""; vin = vehicle.vin ?? ""; mileage = vehicle.currentMileage
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = vehicle == nil ? "Araç Ekle" : "Aracı Düzenle"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Vazgeç", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kaydet", style: .done, target: self, action: #selector(save))
        registerCells(); tableView.keyboardDismissMode = .onDrag
    }

    private func registerCells() {
        ["TextInputCell", "DecimalInputCell", "SelectionCell", "AttachmentPickerCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: .main), forCellReuseIdentifier: $0)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = Row(rawValue: indexPath.row) else { return UITableViewCell() }
        switch row {
        case .nickname, .make, .model, .plate, .vin:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextInputCell", for: indexPath) as! TextInputCell
            let config: (String, String, (String) -> Void) = {
                switch row {
                case .nickname: ("Araç adı", nickname, { self.nickname = $0 })
                case .make: ("Marka", make, { self.make = $0 })
                case .model: ("Model", model, { self.model = $0 })
                case .plate: ("Plaka (isteğe bağlı)", plate, { self.plate = $0.uppercased(with: Locale(identifier: "tr_TR")) })
                default: ("Şasi numarası (isteğe bağlı)", vin, { self.vin = $0.uppercased() })
                }
            }()
            cell.fieldTitleLabel.text = config.0; cell.textField.text = config.1; cell.textField.placeholder = config.0
            cell.textField.accessibilityLabel = config.0
            cell.textField.addAction(UIAction { action in config.2((action.sender as? UITextField)?.text ?? "") }, for: .editingChanged)
            return cell
        case .year, .mileage:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DecimalInputCell", for: indexPath) as! DecimalInputCell
            cell.fieldTitleLabel.text = row == .year ? "Model yılı" : "Güncel kilometre"
            cell.textField.keyboardType = .numberPad
            cell.textField.text = row == .year ? modelYear.map(String.init) : String(mileage)
            cell.textField.addAction(UIAction { [weak self] action in
                let text = (action.sender as? UITextField)?.text ?? ""
                if row == .year { self?.modelYear = Int(text) } else { self?.mileage = Int64(text) ?? 0 }
            }, for: .editingChanged)
            return cell
        case .fuel, .transmission:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectionCell", for: indexPath) as! SelectionCell
            cell.fieldTitleLabel.text = row == .fuel ? "Yakıt türü" : "Şanzıman"
            cell.valueLabel.text = row == .fuel ? fuelType?.displayName : transmission?.displayName
            return cell
        case .photo:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AttachmentPickerCell", for: indexPath) as! AttachmentPickerCell
            cell.fieldTitleLabel.text = "Araç fotoğrafı"
            cell.actionButton.setTitle(pendingPhotoData == nil ? "Fotoğraf Seç" : "Fotoğraf Seçildi", for: .normal)
            cell.actionButton.addTarget(self, action: #selector(selectPhoto), for: .touchUpInside)
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = Row(rawValue: indexPath.row) else { return }
        if row == .fuel {
            presentChoices(title: "Yakıt türü", choices: FuelType.allCases.map { ($0.displayName, $0) }) { self.fuelType = $0 }
        } else if row == .transmission {
            presentChoices(title: "Şanzıman", choices: TransmissionType.allCases.map { ($0.displayName, $0) }) { self.transmission = $0 }
        }
    }

    private func presentChoices<T>(title: String, choices: [(String, T)], selection: @escaping (T) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        choices.forEach { name, value in alert.addAction(UIAlertAction(title: name, style: .default) { _ in selection(value); self.tableView.reloadData() }) }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel)); present(alert, animated: true)
    }

    @objc private func selectPhoto() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared()); configuration.filter = .images; configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration); picker.delegate = self; present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let data = (object as? UIImage)?.jpegData(compressionQuality: 0.82) else { return }
            DispatchQueue.main.async { self?.pendingPhotoData = data; self?.tableView.reloadData() }
        }
    }

    @objc private func save() {
        view.endEditing(true)
        let now = Date.now
        var result = vehicle ?? Vehicle(nickname: nickname, make: make, model: model)
        result.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        result.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
        result.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        result.modelYear = modelYear; result.fuelType = fuelType; result.transmissionType = transmission
        result.plateNumber = plate.isEmpty ? nil : plate; result.vin = vin.isEmpty ? nil : vin
        result.currentMileage = mileage; result.updatedAt = now
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
            } catch { navigationItem.rightBarButtonItem?.isEnabled = true; presentError(error) }
        }
    }

    @objc private func cancel() { dismiss(animated: true) }
}

private extension FuelType {
    var displayName: String { switch self { case .gasoline: "Benzin"; case .diesel: "Dizel"; case .lpg: "LPG"; case .hybrid: "Hibrit"; case .electric: "Elektrik"; case .other: "Diğer" } }
}
private extension TransmissionType {
    var displayName: String { switch self { case .manual: "Manuel"; case .automatic: "Otomatik"; case .semiAutomatic: "Yarı otomatik"; case .other: "Diğer" } }
}
