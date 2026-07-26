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
    private let catalogService: VehicleCatalogService
    private var vehicle: Vehicle?
    private var nickname = "", make = "", model = "", plate = "", vin = ""
    private var modelYear: Int?, mileage: Int64 = 0
    private var fuelType: FuelType?, transmission: TransmissionType?
    private var catalog: VehicleCatalog?
    private var catalogMakeID: String?
    private var catalogModelID: String?
    private var pendingPhotoData: Data?
    private var pendingPhotoImage: UIImage?
    private var existingPhotoImage: UIImage?
    private var photoLoadTask: Task<Void, Never>?
    private var catalogLoadTask: Task<Void, Never>?
#if DEBUG
    private var didPresentScreenshotBrandPicker = false
#endif

    init(
        vehicle: Vehicle?,
        repository: VehicleRepository,
        storage: FileStorageService,
        catalogService: VehicleCatalogService
    ) {
        self.vehicle = vehicle
        self.repository = repository
        self.storage = storage
        self.catalogService = catalogService
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
            catalogMakeID = vehicle.catalogMakeID
            catalogModelID = vehicle.catalogModelID
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
        loadCatalog()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
#if DEBUG
        presentScreenshotBrandPickerIfNeeded()
#endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        photoLoadTask?.cancel()
        catalogLoadTask?.cancel()
    }

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
            cell.configureSelection(title: "Marka", value: normalized(make), placeholder: catalog == nil ? "Katalog yükleniyor…" : "Seçiniz")
        case .model:
            cell.configureSelection(title: "Model", value: normalized(model), placeholder: "Önce marka seçin", isEnabled: !make.isEmpty)
        case .year:
            cell.configureSelection(
                title: "Yıl",
                value: modelYear.map(String.init),
                placeholder: "Önce model seçin",
                isEnabled: !model.isEmpty
            )
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
        if row == .make { presentMakeChoices() }
        if row == .model { presentModelChoices() }
        if row == .year { presentYearChoices() }
        if row == .fuel { presentFuelChoices() }
        if row == .transmission { presentTransmissionChoices() }
    }

    private func loadCatalog() {
        catalogLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                catalog = try await catalogService.catalog()
                guard !Task.isCancelled else { return }
                tableView.reloadRows(
                    at: [
                        IndexPath(row: Row.make.rawValue, section: Section.fields.rawValue),
                        IndexPath(row: Row.model.rawValue, section: Section.fields.rawValue),
                        IndexPath(row: Row.year.rawValue, section: Section.fields.rawValue)
                    ],
                    with: .none
                )
#if DEBUG
                presentScreenshotBrandPickerIfNeeded()
#endif
            } catch {
                presentError(GarageError.validation("Araç kataloğu yüklenemedi. Lütfen tekrar deneyin."))
            }
        }
    }

#if DEBUG
    private func presentScreenshotBrandPickerIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-screenshotBrandPicker"),
              catalog != nil,
              viewIfLoaded?.window != nil,
              !didPresentScreenshotBrandPicker else {
            return
        }
        didPresentScreenshotBrandPicker = true
        presentMakeChoices()
    }
#endif

    private func presentMakeChoices() {
        guard let catalog else { return }
        let makes = catalog.makes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let options = makes.map {
            SelectionSheetOption(
                title: $0.name,
                imageName: "VehiclePlaceholder"
            )
        }
            + [SelectionSheetOption(title: "Diğer / Manuel Gir", symbolName: "square.and.pencil")]
        presentSelectionSheet(
            title: "Marka",
            message: "Marka değiştirildiğinde model ve yıl seçimi sıfırlanır.",
            options: options,
            selectedIndex: catalogMakeID.flatMap { id in makes.firstIndex { $0.id == id } }
        ) { [weak self] index in
            guard let self else { return }
            if makes.indices.contains(index) {
                let selected = makes[index]
                guard selected.id != catalogMakeID else { return }
                make = selected.name
                catalogMakeID = selected.id
                clearAfterMake()
                reloadCatalogRows()
                updateSaveButtonState()
            } else {
                promptForManualValue(title: "Marka Gir", currentValue: make) { [weak self] value in
                    guard let self else { return }
                    guard catalogMakeID != nil || normalized(make) != value else { return }
                    make = value
                    catalogMakeID = nil
                    clearAfterMake()
                    reloadCatalogRows()
                    updateSaveButtonState()
                }
            }
        }
    }

    private func presentModelChoices() {
        guard !make.isEmpty else { return }
        guard let makeEntry = catalog?.make(id: catalogMakeID) else {
            promptForManualValue(title: "Model Gir", currentValue: model) { [weak self] value in
                guard let self else { return }
                guard catalogModelID != nil || normalized(model) != value else { return }
                model = value
                catalogModelID = nil
                modelYear = nil
                reloadCatalogRows()
                updateSaveButtonState()
            }
            return
        }

        let models = makeEntry.models.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let options = models.map { SelectionSheetOption(title: $0.name, symbolName: "car.side.fill") }
            + [SelectionSheetOption(title: "Diğer / Manuel Gir", symbolName: "square.and.pencil")]
        presentSelectionSheet(
            title: "Model",
            options: options,
            selectedIndex: catalogModelID.flatMap { id in models.firstIndex { $0.id == id } }
        ) { [weak self] index in
            guard let self else { return }
            if models.indices.contains(index) {
                guard models[index].id != catalogModelID else { return }
                model = models[index].name
                catalogModelID = models[index].id
                modelYear = nil
                reloadCatalogRows()
                updateSaveButtonState()
            } else {
                promptForManualValue(title: "Model Gir", currentValue: model) { [weak self] value in
                    guard let self else { return }
                    guard catalogModelID != nil || normalized(model) != value else { return }
                    model = value
                    catalogModelID = nil
                    modelYear = nil
                    reloadCatalogRows()
                    updateSaveButtonState()
                }
            }
        }
    }

    private func presentYearChoices() {
        guard !model.isEmpty else { return }
        let years = defaultYears
        let options = years.map { SelectionSheetOption(title: String($0), symbolName: "calendar") }
            + [SelectionSheetOption(title: "Diğer / Manuel Gir", symbolName: "square.and.pencil")]
        presentSelectionSheet(
            title: "Model Yılı",
            options: options,
            selectedIndex: modelYear.flatMap(years.firstIndex)
        ) { [weak self] index in
            guard let self else { return }
            if years.indices.contains(index) {
                guard years[index] != modelYear else { return }
                modelYear = years[index]
                reloadCatalogRows()
                updateSaveButtonState()
            } else {
                promptForManualValue(
                    title: "Model Yılı Gir",
                    currentValue: modelYear.map(String.init) ?? "",
                    keyboardType: .numberPad
                ) { [weak self] value in
                    guard let self else { return }
                    let selectedYear = Int(value)
                    guard selectedYear != modelYear else { return }
                    modelYear = selectedYear
                    reloadCatalogRows()
                    updateSaveButtonState()
                }
            }
        }
    }

    private func promptForManualValue(
        title: String,
        currentValue: String,
        keyboardType: UIKeyboardType = .default,
        completion: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.text = currentValue
            $0.keyboardType = keyboardType
            $0.autocapitalizationType = keyboardType == .numberPad ? .none : .words
            $0.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
        alert.addAction(UIAlertAction(title: "Kaydet", style: .default) { _ in
            let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty else { return }
            completion(value)
        })
        present(alert, animated: true)
    }

    private func clearAfterMake() {
        model = ""
        catalogModelID = nil
        modelYear = nil
    }

    private func reloadCatalogRows() {
        tableView.reloadRows(
            at: [Row.make, .model, .year].map {
                IndexPath(row: $0.rawValue, section: Section.fields.rawValue)
            },
            with: .none
        )
    }

    private var defaultYears: [Int] {
        let current = Calendar.current.component(.year, from: .now) + 1
        return Array((2000...current).reversed())
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
        selectLocalPhoto()
    }

    private func selectLocalPhoto() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func normalizedPhoto(_ image: UIImage) -> (data: Data, image: UIImage)? {
        let maximumDimension: CGFloat = 1_600
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let scale = min(1, maximumDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalizedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = normalizedImage.jpegData(compressionQuality: 0.84) else { return nil }
        return (data, normalizedImage)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                guard let self, let normalized = self.normalizedPhoto(image) else { return }
                self.pendingPhotoData = normalized.data
                self.pendingPhotoImage = normalized.image
                self.tableView.reloadRows(
                    at: [IndexPath(row: 0, section: Section.photo.rawValue)],
                    with: .none
                )
            }
        }
    }

    private func updateSaveButtonState() {
        let requiredText = [nickname, make, model]
        let hasRequiredText = requiredText.allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        navigationItem.rightBarButtonItem?.isEnabled = hasRequiredText
            && modelYear != nil
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
        result.catalogMakeID = catalogMakeID
        result.catalogModelID = catalogModelID
        result.updatedAt = now
        navigationItem.rightBarButtonItem?.isEnabled = false

        Task {
            var newPhotoPath: String?
            do {
                if let pendingPhotoData {
                    let oldPath = result.photoIdentifier
                    let savedPath = try await storage.save(data: pendingPhotoData, vehicleID: result.id, fileExtension: "jpg")
                    newPhotoPath = savedPath
                    result.photoIdentifier = savedPath
                    if vehicle == nil {
                        try await CreateVehicleUseCase(repository: repository).execute(result)
                    } else {
                        try await UpdateVehicleUseCase(repository: repository).execute(
                            result,
                            expectedUpdatedAt: vehicle?.updatedAt
                        )
                    }
                    if let oldPath, oldPath != savedPath {
                        try? await storage.delete(relativePath: oldPath)
                    }
                } else if vehicle == nil {
                    try await CreateVehicleUseCase(repository: repository).execute(result)
                } else {
                    try await UpdateVehicleUseCase(repository: repository).execute(
                        result,
                        expectedUpdatedAt: vehicle?.updatedAt
                    )
                }
                onSaved?(result)
            } catch {
                if let newPhotoPath {
                    try? await storage.delete(relativePath: newPhotoPath)
                }
                updateSaveButtonState()
                presentError(error)
            }
        }
    }

    @objc private func cancel() { dismiss(animated: true) }

    private func normalized(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

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
