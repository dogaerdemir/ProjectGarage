//
//  Created by Doğa Erdemir on 12.07.2026.
//

import PhotosUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

final class RecordEditorViewController: UITableViewController {
    struct PendingAttachment {
        let data: Data; let name: String; let mimeType: String; let fileExtension: String; let type: DocumentType
    }

    var onSaved: ((VehicleRecord) -> Void)?
    private let vehicle: Vehicle
    private let existing: VehicleRecord?
    private let recordRepository: VehicleRecordRepository
    private let vehicleRepository: VehicleRepository
    private let reminderRepository: ReminderRepository
    private let documentRepository: DocumentRepository
    private let storage: FileStorageService
    private let notificationService: NotificationSchedulingService
    private var lineItems: [RecordLineItem] = []
    private var attachments: [PendingAttachment] = []

    private var type: RecordType
    private var recordTitle = "", vendor = "", notes = "", category = "", policyNumber = "", outcome = ""
    private var date = Date.now, startDate = Date.now, endDate: Date?, validityDate: Date?
    private var odometer: Int64?, amount: Decimal?, liters: Decimal?, unitPrice: Decimal?, fullTank = false
    private var reminderDate: Date?, reminderMileage: Int64?

    private enum Field: Hashable {
        case title, date, odometer, amount, vendor, notes, category, liters, unitPrice, fullTank
        case policyNumber, startDate, endDate, validityDate, outcome, reminderDate, reminderMileage, attachment
    }

    init(
        vehicle: Vehicle, type: RecordType, existing: VehicleRecord? = nil,
        recordRepository: VehicleRecordRepository, vehicleRepository: VehicleRepository,
        reminderRepository: ReminderRepository, documentRepository: DocumentRepository,
        storage: FileStorageService, notificationService: NotificationSchedulingService
    ) {
        self.vehicle = vehicle; self.type = existing?.recordType ?? type; self.existing = existing
        self.recordRepository = recordRepository; self.vehicleRepository = vehicleRepository
        self.reminderRepository = reminderRepository; self.documentRepository = documentRepository
        self.storage = storage; self.notificationService = notificationService
        super.init(style: .insetGrouped)
        if let existing {
            recordTitle = existing.title; vendor = existing.vendorName ?? ""; notes = existing.notes ?? ""
            date = existing.eventDate; odometer = existing.odometer; amount = existing.totalAmount
            liters = existing.liters; unitPrice = existing.unitPrice; fullTank = existing.isFullTank ?? false
            category = existing.policyType ?? existing.inspectionType ?? ""
            policyNumber = existing.policyNumber ?? ""; startDate = existing.startDate ?? existing.eventDate
            endDate = existing.endDate; validityDate = existing.validityDate; outcome = existing.outcome ?? ""
        } else {
            odometer = vehicle.currentMileage
            if type == .insurance { endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) }
            if type == .inspection { validityDate = Calendar.current.date(byAdding: .year, value: 2, to: .now) }
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad(); title = existing == nil ? "\(type.displayName) Ekle" : "Kaydı Düzenle"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Vazgeç", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kaydet", style: .done, target: self, action: #selector(save))
        ["TextInputCell", "DecimalInputCell", "DatePickerCell", "SelectionCell", "ToggleCell", "MultilineTextCell", "AttachmentPickerCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: .main), forCellReuseIdentifier: $0)
        }
        tableView.keyboardDismissMode = .onDrag
        if let existing { Task { lineItems = (try? await recordRepository.lineItems(recordID: existing.id)) ?? []; tableView.reloadData() } }
    }

    private var fields: [Field] {
        switch type {
        case .maintenance: [.title, .date, .odometer, .vendor, .amount, .notes, .reminderDate, .reminderMileage, .attachment]
        case .fuel: [.date, .odometer, .liters, .unitPrice, .amount, .vendor, .fullTank, .notes, .attachment]
        case .expense: [.category, .title, .date, .amount, .vendor, .odometer, .notes, .attachment]
        case .insurance: [.category, .vendor, .policyNumber, .startDate, .endDate, .amount, .notes, .attachment]
        case .inspection: [.category, .date, .validityDate, .odometer, .outcome, .amount, .notes, .attachment]
        case .mileage: [.date, .odometer, .notes]
        case .note: [.title, .date, .odometer, .notes, .attachment]
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { type == .maintenance ? 2 : 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? fields.count : lineItems.count + 1
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 1 ? "İşlem Kalemleri" : nil }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            if indexPath.row == lineItems.count {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil); cell.textLabel?.text = "İşlem Kalemi Ekle"
                cell.textLabel?.textColor = UIColor(named: "AppAccent"); cell.imageView?.image = UIImage(systemName: "plus.circle.fill"); return cell
            }
            let item = lineItems[indexPath.row]; let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = item.name; cell.detailTextLabel?.text = item.category; cell.accessoryType = .disclosureIndicator; return cell
        }
        let field = fields[indexPath.row]
        switch field {
        case .title, .vendor, .category, .policyNumber, .outcome:
            let cell = tableView.dequeueReusableCell(withIdentifier: field == .category ? "SelectionCell" : "TextInputCell", for: indexPath)
            if let selection = cell as? SelectionCell {
                selection.fieldTitleLabel.text = categoryTitle; selection.valueLabel.text = category.isEmpty ? "Seç" : category
            } else if let input = cell as? TextInputCell {
                let data = textData(for: field); input.fieldTitleLabel.text = data.0; input.textField.text = data.1
                input.textField.placeholder = data.0; input.textField.accessibilityLabel = data.0
                input.textField.addAction(UIAction { [weak self] action in self?.setText((action.sender as? UITextField)?.text ?? "", field: field) }, for: .editingChanged)
            }
            return cell
        case .date, .startDate, .endDate, .validityDate, .reminderDate:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DatePickerCell", for: indexPath) as! DatePickerCell
            cell.fieldTitleLabel.text = dateTitle(for: field); cell.datePicker.datePickerMode = .date
            cell.datePicker.date = dateValue(for: field) ?? .now
            cell.datePicker.addAction(UIAction { [weak self] action in self?.setDate((action.sender as? UIDatePicker)?.date ?? .now, field: field) }, for: .valueChanged)
            return cell
        case .odometer, .amount, .liters, .unitPrice, .reminderMileage:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DecimalInputCell", for: indexPath) as! DecimalInputCell
            cell.fieldTitleLabel.text = numberTitle(for: field); cell.textField.text = numberText(for: field)
            cell.textField.keyboardType = field == .odometer || field == .reminderMileage ? .numberPad : .decimalPad
            cell.textField.addAction(UIAction { [weak self] action in self?.setNumber((action.sender as? UITextField)?.text ?? "", field: field) }, for: .editingChanged)
            return cell
        case .fullTank:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
            cell.fieldTitleLabel.text = "Tam depo"; cell.toggle.isOn = fullTank
            cell.toggle.addAction(UIAction { [weak self] action in self?.fullTank = (action.sender as? UISwitch)?.isOn ?? false }, for: .valueChanged); return cell
        case .notes:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MultilineTextCell", for: indexPath) as! MultilineTextCell
            cell.fieldTitleLabel.text = "Notlar"; cell.textView.text = notes; cell.textView.delegate = self; return cell
        case .attachment:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AttachmentPickerCell", for: indexPath) as! AttachmentPickerCell
            cell.fieldTitleLabel.text = "Belgeler"; cell.actionButton.setTitle(attachments.isEmpty ? "Belge Ekle" : "\(attachments.count) belge", for: .normal)
            cell.actionButton.addTarget(self, action: #selector(addAttachment), for: .touchUpInside); return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            indexPath.row == lineItems.count ? editLineItem(nil) : editLineItem(indexPath.row); return
        }
        if fields[indexPath.row] == .category { chooseCategory() }
    }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1, indexPath.row < lineItems.count else { return nil }
        return UISwipeActionsConfiguration(actions: [UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in self?.lineItems.remove(at: indexPath.row); self?.tableView.reloadSections(IndexSet(integer: 1), with: .automatic); done(true) }])
    }

    private var categoryTitle: String { switch type { case .expense: "Kategori"; case .insurance: "Sigorta türü"; case .inspection: "Kontrol türü"; default: "Kategori" } }
    private func categories() -> [String] {
        switch type {
        case .expense: ["Otopark", "Otoyol", "Yıkama", "Aksesuar", "Vergi", "Ceza", "Çekici", "Ekspertiz", "Diğer"]
        case .insurance: ["Zorunlu trafik sigortası", "Kasko", "Diğer"]
        case .inspection: ["Araç muayenesi", "Egzoz ölçümü", "Ekspertiz", "Servis kontrolü", "Diğer"]
        default: []
        }
    }
    private func chooseCategory() {
        let alert = UIAlertController(title: categoryTitle, message: nil, preferredStyle: .actionSheet)
        categories().forEach { value in alert.addAction(UIAlertAction(title: value, style: .default) { _ in self.category = value; self.tableView.reloadData() }) }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel)); present(alert, animated: true)
    }
    private func textData(for field: Field) -> (String, String) {
        switch field { case .title: (type == .expense ? "Açıklama" : "Başlık", recordTitle); case .vendor: (type == .fuel ? "İstasyon" : type == .insurance ? "Şirket" : type == .maintenance ? "Servis" : "İşletme", vendor); case .policyNumber: ("Poliçe numarası", policyNumber); case .outcome: ("Sonuç", outcome); default: ("", "") }
    }
    private func setText(_ value: String, field: Field) { switch field { case .title: recordTitle = value; case .vendor: vendor = value; case .policyNumber: policyNumber = value; case .outcome: outcome = value; default: break } }
    private func dateTitle(for field: Field) -> String { switch field { case .date: "Tarih"; case .startDate: "Başlangıç"; case .endDate: "Bitiş"; case .validityDate: "Geçerlilik tarihi"; case .reminderDate: "Sonraki bakım tarihi"; default: "Tarih" } }
    private func dateValue(for field: Field) -> Date? { switch field { case .date: date; case .startDate: startDate; case .endDate: endDate; case .validityDate: validityDate; case .reminderDate: reminderDate; default: nil } }
    private func setDate(_ value: Date, field: Field) { switch field { case .date: date = value; case .startDate: startDate = value; case .endDate: endDate = value; case .validityDate: validityDate = value; case .reminderDate: reminderDate = value; default: break } }
    private func numberTitle(for field: Field) -> String { switch field { case .odometer: "Kilometre"; case .amount: "Toplam tutar"; case .liters: "Litre"; case .unitPrice: "Litre fiyatı"; case .reminderMileage: "Sonraki bakım kilometresi"; default: "" } }
    private func numberText(for field: Field) -> String { switch field { case .odometer: odometer.map(String.init) ?? ""; case .amount: amount.map(String.init(describing:)) ?? ""; case .liters: liters.map(String.init(describing:)) ?? ""; case .unitPrice: unitPrice.map(String.init(describing:)) ?? ""; case .reminderMileage: reminderMileage.map(String.init) ?? ""; default: "" } }
    private func decimal(_ text: String) -> Decimal? { Decimal(string: text.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) }
    private func setNumber(_ text: String, field: Field) {
        switch field { case .odometer: odometer = Int64(text); case .amount: amount = decimal(text); case .liters: liters = decimal(text); case .unitPrice: unitPrice = decimal(text); case .reminderMileage: reminderMileage = Int64(text); default: break }
        if type == .fuel {
            let values = CalculateFuelValuesUseCase().execute(liters: liters, unitPrice: unitPrice, total: amount)
            liters = values.0; unitPrice = values.1; amount = values.2
            if field != .amount, let index = fields.firstIndex(of: .amount), let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? DecimalInputCell {
                cell.textField.text = amount.map(String.init(describing:)) ?? ""
            }
        }
    }

    private func editLineItem(_ index: Int?) {
        let alert = UIAlertController(title: index == nil ? "İşlem Kalemi Ekle" : "İşlem Kalemini Düzenle", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "İşlem adı"; if let index { $0.text = self.lineItems[index].name } }
        alert.addTextField { $0.placeholder = "Kategori"; if let index { $0.text = self.lineItems[index].category } }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
        alert.addAction(UIAlertAction(title: "Kaydet", style: .default) { _ in
            guard let name = alert.textFields?[0].text, !name.isEmpty else { return }
            let item = RecordLineItem(id: index.map { self.lineItems[$0].id } ?? UUID(), recordID: self.existing?.id ?? UUID(), name: name, category: alert.textFields?[1].text, sortOrder: index ?? self.lineItems.count)
            if let index { self.lineItems[index] = item } else { self.lineItems.append(item) }
            self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
        })
        present(alert, animated: true)
    }

    @objc private func addAttachment() {
        let alert = UIAlertController(title: "Belge Ekle", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Dosyalar’dan Seç", style: .default) { _ in self.pickFile() })
        alert.addAction(UIAlertAction(title: "Fotoğraflar’dan Seç", style: .default) { _ in self.pickPhoto() })
        if VNDocumentCameraViewController.isSupported { alert.addAction(UIAlertAction(title: "Belge Tara", style: .default) { _ in self.scanDocument() }) }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel)); present(alert, animated: true)
    }
    private func pickFile() { let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true); picker.delegate = self; present(picker, animated: true) }
    private func pickPhoto() { var config = PHPickerConfiguration(photoLibrary: .shared()); config.filter = .images; config.selectionLimit = 5; let picker = PHPickerViewController(configuration: config); picker.delegate = self; present(picker, animated: true) }
    private func scanDocument() { let scanner = VNDocumentCameraViewController(); scanner.delegate = self; present(scanner, animated: true) }

    @objc private func save() {
        view.endEditing(true)
        let defaultTitle = type.displayName
        let id = existing?.id ?? UUID()
        let normalizedItems = lineItems.enumerated().map { index, item in RecordLineItem(id: item.id, recordID: id, name: item.name, category: item.category, brand: item.brand, partNumber: item.partNumber, amount: item.amount, warrantyEndDate: item.warrantyEndDate, notes: item.notes, sortOrder: index) }
        var record = VehicleRecord(
            id: id, vehicleID: vehicle.id, recordType: type,
            title: recordTitle.isEmpty ? (category.isEmpty ? defaultTitle : category) : recordTitle,
            eventDate: type == .insurance ? startDate : date, odometer: odometer, totalAmount: amount,
            vendorName: vendor.isEmpty ? nil : vendor, notes: notes.isEmpty ? nil : notes,
            liters: liters, unitPrice: unitPrice, isFullTank: type == .fuel ? fullTank : nil,
            policyType: type == .insurance || type == .expense ? category : nil, policyNumber: policyNumber.isEmpty ? nil : policyNumber,
            startDate: type == .insurance ? startDate : nil, endDate: type == .insurance ? endDate : nil,
            inspectionType: type == .inspection ? category : nil, validityDate: type == .inspection ? validityDate : nil,
            outcome: outcome.isEmpty ? nil : outcome, createdAt: existing?.createdAt ?? .now, updatedAt: .now
        )
        navigationItem.rightBarButtonItem?.isEnabled = false
        Task {
            do {
                if existing == nil { try await CreateRecordUseCase(recordRepository: recordRepository, vehicleRepository: vehicleRepository).execute(record, lineItems: normalizedItems) }
                else { try await UpdateRecordUseCase(recordRepository: recordRepository, vehicleRepository: vehicleRepository).execute(record, lineItems: normalizedItems) }
                for attachment in attachments {
                    _ = try await AttachDocumentUseCase(repository: documentRepository, storage: storage).execute(data: attachment.data, vehicleID: vehicle.id, recordID: id, type: attachment.type, displayName: attachment.name, mimeType: attachment.mimeType, fileExtension: attachment.fileExtension)
                }
                let dueDate = reminderDate ?? (type == .insurance ? endDate : type == .inspection ? validityDate : nil)
                if dueDate != nil || reminderMileage != nil {
                    let reminder = Reminder(vehicleID: vehicle.id, recordID: id, title: "\(record.title) zamanı", dueDate: dueDate, dueMileage: reminderMileage)
                    try await CreateReminderUseCase(repository: reminderRepository, notificationService: notificationService).execute(reminder)
                }
                onSaved?(record)
            } catch { navigationItem.rightBarButtonItem?.isEnabled = true; presentError(error) }
        }
    }
    @objc private func cancel() { dismiss(animated: true) }
}

extension RecordEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) { notes = textView.text }
}
extension RecordEditorViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) { attachments.append(PendingAttachment(data: data, name: url.lastPathComponent, mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", fileExtension: url.pathExtension, type: documentType)) }
        }
        tableView.reloadData()
    }
}
extension RecordEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results where result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                guard let data = (image as? UIImage)?.jpegData(compressionQuality: 0.86) else { return }
                DispatchQueue.main.async { self?.attachments.append(PendingAttachment(data: data, name: "Belge.jpg", mimeType: "image/jpeg", fileExtension: "jpg", type: self?.documentType ?? .other)); self?.tableView.reloadData() }
            }
        }
    }
}
extension RecordEditorViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        for index in 0..<scan.pageCount where index < 10 {
            if let data = scan.imageOfPage(at: index).jpegData(compressionQuality: 0.86) { attachments.append(PendingAttachment(data: data, name: "Tarama-\(index + 1).jpg", mimeType: "image/jpeg", fileExtension: "jpg", type: documentType)) }
        }
        tableView.reloadData()
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { controller.dismiss(animated: true) }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { controller.dismiss(animated: true); presentError(error) }
}
private extension RecordEditorViewController {
    var documentType: DocumentType { switch type { case .maintenance: .serviceInvoice; case .fuel: .fuelReceipt; case .insurance: .insurancePolicy; case .inspection: .inspectionDocument; default: .other } }
}
