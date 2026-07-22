//
//  Created by Doğa Erdemir on 12.07.2026.
//

import PhotosUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

final class RecordEditorViewController: UITableViewController {
    struct PendingAttachment {
        let data: Data
        let name: String
        let mimeType: String
        let fileExtension: String
        let type: DocumentType
    }

    private struct FormSection {
        let title: String
        let footer: String?
        let fields: [Field]

        init(title: String, footer: String? = nil, fields: [Field]) {
            self.title = title
            self.footer = footer
            self.fields = fields
        }
    }

    private enum TableSection {
        case fields(FormSection)
        case lineItems
    }

    private enum Field: Hashable {
        case title, date, odometer, amount, vendor, notes, category, liters, unitPrice, fullTank
        case policyNumber, startDate, endDate, validityDate, outcome
        case useReminderDate, reminderDate, useReminderMileage, reminderMileage, attachment
    }

    private enum AttachmentSource {
        case files, photos, scanner

        var option: SelectionSheetOption {
            switch self {
            case .files: SelectionSheetOption(title: "Dosyalar’dan Seç", subtitle: "PDF veya görsel", symbolName: "folder.fill")
            case .photos: SelectionSheetOption(title: "Fotoğraflar’dan Seç", subtitle: "En fazla 5 görsel", symbolName: "photo.on.rectangle.angled")
            case .scanner: SelectionSheetOption(title: "Belge Tara", subtitle: "Kamerayla yeni tarama", symbolName: "doc.viewfinder.fill")
            }
        }
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
    private let recordID: UUID
    private let reminderID = UUID()
    private var lineItems: [RecordLineItem] = []
    private var attachments: [PendingAttachment] = []
    private var existingAttachments: [GarageDocument] = []
    private var isLoadingExistingContent = false
    private var pendingPhotoLoads = 0
    private var isSaving = false

    private var type: RecordType
    private var recordTitle = "", vendor = "", notes = "", category = "", policyNumber = "", outcome = ""
    private var date = Date.now, startDate = Date.now, endDate: Date?, validityDate: Date?
    private var odometer: Int64?, amount: Decimal?, liters: Decimal?, unitPrice: Decimal?, fullTank = false
    private var reminderDate: Date?, reminderMileage: Int64?
    private var usesReminderDate = false, usesReminderMileage = false

    init(
        vehicle: Vehicle, type: RecordType, existing: VehicleRecord? = nil,
        recordRepository: VehicleRecordRepository, vehicleRepository: VehicleRepository,
        reminderRepository: ReminderRepository, documentRepository: DocumentRepository,
        storage: FileStorageService, notificationService: NotificationSchedulingService
    ) {
        self.vehicle = vehicle
        self.type = existing?.recordType ?? type
        self.existing = existing
        self.recordRepository = recordRepository
        self.vehicleRepository = vehicleRepository
        self.reminderRepository = reminderRepository
        self.documentRepository = documentRepository
        self.storage = storage
        self.notificationService = notificationService
        recordID = existing?.id ?? UUID()
        super.init(style: .insetGrouped)
        if let existing {
            recordTitle = existing.title
            vendor = existing.vendorName ?? ""
            notes = existing.notes ?? ""
            date = existing.eventDate
            odometer = existing.odometer
            amount = existing.totalAmount
            liters = existing.liters
            unitPrice = existing.unitPrice
            fullTank = existing.isFullTank ?? false
            category = existing.policyType ?? existing.inspectionType ?? ""
            policyNumber = existing.policyNumber ?? ""
            startDate = existing.startDate ?? existing.eventDate
            endDate = existing.endDate
            validityDate = existing.validityDate
            outcome = existing.outcome ?? ""
        } else {
            odometer = vehicle.currentMileage
            if type == .insurance { endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) }
            if type == .inspection { validityDate = Calendar.current.date(byAdding: .year, value: 2, to: .now) }
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existing == nil ? "\(type.displayName) Ekle" : "Kaydı Düzenle"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Vazgeç", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kaydet", style: .done, target: self, action: #selector(save))
        ["TextInputCell", "DecimalInputCell", "DatePickerCell", "SelectionCell", "ToggleCell", "MultilineTextCell", "AttachmentPickerCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: .main), forCellReuseIdentifier: $0)
        }
        AppTheme.styleForm(tableView)
        isLoadingExistingContent = existing != nil
        updateSaveButtonState()
        loadExistingContent()
    }

    private func loadExistingContent() {
        guard let existing else { return }
        isLoadingExistingContent = true
        updateSaveButtonState()
        Task {
            do {
                async let items = recordRepository.lineItems(recordID: existing.id)
                async let documents = documentRepository.fetchDocuments(vehicleID: existing.vehicleID)
                lineItems = try await items
                let fetchedDocuments = try await documents
                existingAttachments = fetchedDocuments.filter { $0.recordID == existing.id }
                isLoadingExistingContent = false
                updateSaveButtonState()
                tableView.reloadData()
            } catch {
                presentExistingContentLoadError(error)
            }
        }
    }

    private func presentExistingContentLoadError(_ error: Error) {
        let alert = UIAlertController(
            title: "Kayıt Yüklenemedi",
            message: "İşlem kalemleri ve belgeler alınamadığı için kayıt güvenli biçimde düzenlenemiyor.\n\n\(error.localizedDescription)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Kapat", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Tekrar Dene", style: .default) { [weak self] _ in
            self?.loadExistingContent()
        })
        present(alert, animated: true)
    }

    private var formSections: [FormSection] {
        switch type {
        case .maintenance:
            var reminderFields: [Field] = [.useReminderDate]
            if usesReminderDate { reminderFields.append(.reminderDate) }
            reminderFields.append(.useReminderMileage)
            if usesReminderMileage { reminderFields.append(.reminderMileage) }
            return [
                FormSection(title: "İşlem", fields: [.title, .date, .odometer, .vendor]),
                FormSection(title: "Tutar ve Açıklama", fields: [.amount, .notes]),
                FormSection(title: "Hatırlatma", footer: "İsterseniz bir sonraki bakım için tarih veya kilometre hedefi oluşturun.", fields: reminderFields),
                FormSection(title: "Belgeler", footer: "Fatura, servis formu veya fotoğraf ekleyebilirsiniz.", fields: [.attachment])
            ]
        case .fuel:
            return [
                FormSection(title: "Yakıt Alımı", fields: [.date, .odometer, .vendor, .fullTank]),
                FormSection(title: "Miktar ve Tutar", footer: "İki değer girildiğinde üçüncü değer otomatik hesaplanır.", fields: [.liters, .unitPrice, .amount]),
                FormSection(title: "Notlar ve Belgeler", fields: [.notes, .attachment])
            ]
        case .expense:
            return [
                FormSection(title: "Masraf", fields: [.category, .title, .date]),
                FormSection(title: "Tutar ve Konum", fields: [.amount, .vendor, .odometer]),
                FormSection(title: "Notlar ve Belgeler", fields: [.notes, .attachment])
            ]
        case .insurance:
            return [
                FormSection(title: "Poliçe", fields: [.category, .vendor, .policyNumber]),
                FormSection(title: "Tarih ve Tutar", fields: [.startDate, .endDate, .amount]),
                FormSection(title: "Notlar ve Belgeler", fields: [.notes, .attachment])
            ]
        case .inspection:
            return [
                FormSection(title: "Kontrol", fields: [.category, .date, .validityDate, .outcome]),
                FormSection(title: "Kilometre ve Tutar", fields: [.odometer, .amount]),
                FormSection(title: "Notlar ve Belgeler", fields: [.notes, .attachment])
            ]
        case .mileage:
            return [FormSection(title: "Kilometre Güncelleme", footer: "Hatalı bir değeri düzeltmek için daha düşük bir kilometre de kaydedebilirsiniz.", fields: [.date, .odometer, .notes])]
        case .note:
            return [
                FormSection(title: "Not", fields: [.title, .date, .odometer, .notes]),
                FormSection(title: "Belgeler", fields: [.attachment])
            ]
        }
    }

    private var tableSections: [TableSection] {
        var result = formSections.map(TableSection.fields)
        if type == .maintenance { result.insert(.lineItems, at: min(2, result.count)) }
        return result
    }

    private var lineItemsSectionIndex: Int? {
        tableSections.firstIndex { if case .lineItems = $0 { return true }; return false }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { tableSections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableSections[section] {
        case let .fields(section): section.fields.count
        case .lineItems: lineItems.count + 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch tableSections[section] {
        case let .fields(section): section.title
        case .lineItems: "İşlem Kalemleri"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if case let .fields(section) = tableSections[section] { return section.footer }
        return nil
    }

    private func field(at indexPath: IndexPath) -> Field? {
        guard case let .fields(section) = tableSections[indexPath.section], section.fields.indices.contains(indexPath.row) else { return nil }
        return section.fields[indexPath.row]
    }

    private func indexPath(for field: Field) -> IndexPath? {
        for (sectionIndex, section) in tableSections.enumerated() {
            guard case let .fields(formSection) = section, let row = formSection.fields.firstIndex(of: field) else { continue }
            return IndexPath(row: row, section: sectionIndex)
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if case .lineItems = tableSections[indexPath.section] {
            if indexPath.row == lineItems.count {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                var content = cell.defaultContentConfiguration()
                content.text = "İşlem Kalemi Ekle"
                content.textProperties.color = AppTheme.accentColor
                content.textProperties.font = AppTheme.font(.body, weight: .semibold)
                content.image = UIImage(systemName: "plus.circle.fill")
                content.imageProperties.tintColor = AppTheme.accentColor
                cell.contentConfiguration = content
                return cell
            }
            let item = lineItems[indexPath.row]
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            var content = UIListContentConfiguration.subtitleCell()
            content.text = item.name
            content.secondaryText = item.category
            content.textProperties.font = AppTheme.font(.body, weight: .medium)
            content.secondaryTextProperties.color = AppTheme.secondaryTextColor
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        }

        guard let field = field(at: indexPath) else { return UITableViewCell() }
        switch field {
        case .title, .vendor, .policyNumber, .outcome:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextInputCell", for: indexPath) as! TextInputCell
            let data = textData(for: field)
            cell.configure(title: data.title, value: data.value, placeholder: data.placeholder, autocapitalizationType: data.capitalization) { [weak self] value in
                self?.setText(value, field: field)
            }
            return cell

        case .category:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectionCell", for: indexPath) as! SelectionCell
            cell.configure(title: categoryTitle, value: category.isEmpty ? nil : category)
            return cell

        case .date, .startDate, .endDate, .validityDate, .reminderDate:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DatePickerCell", for: indexPath) as! DatePickerCell
            cell.configure(title: dateTitle(for: field), date: dateValue(for: field) ?? .now) { [weak self] value in
                self?.setDate(value, field: field)
            }
            return cell

        case .odometer, .amount, .liters, .unitPrice, .reminderMileage:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DecimalInputCell", for: indexPath) as! DecimalInputCell
            let isMileage = field == .odometer || field == .reminderMileage
            cell.configure(
                title: numberTitle(for: field),
                value: numberText(for: field),
                placeholder: numberPlaceholder(for: field),
                keyboardType: isMileage ? .numberPad : .decimalPad,
                suffix: numberSuffix(for: field)
            ) { [weak self] value in self?.setNumber(value, field: field) }
            return cell

        case .fullTank:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
            cell.configure(title: "Tam depo", isOn: fullTank) { [weak self] in self?.fullTank = $0 }
            return cell

        case .useReminderDate:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
            cell.configure(title: "Tarih hatırlatması", isOn: usesReminderDate) { [weak self] enabled in
                self?.usesReminderDate = enabled
                self?.reminderDate = enabled ? (self?.reminderDate ?? Calendar.current.date(byAdding: .month, value: 6, to: .now)) : nil
                self?.tableView.reloadData()
            }
            return cell

        case .useReminderMileage:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
            cell.configure(title: "Kilometre hatırlatması", isOn: usesReminderMileage) { [weak self] enabled in
                self?.usesReminderMileage = enabled
                if !enabled { self?.reminderMileage = nil }
                self?.tableView.reloadData()
            }
            return cell

        case .notes:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MultilineTextCell", for: indexPath) as! MultilineTextCell
            cell.configure(title: "Notlar · isteğe bağlı", text: notes, placeholder: "İşlemle ilgili not ekleyin") { [weak self] in self?.notes = $0 }
            return cell

        case .attachment:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AttachmentPickerCell", for: indexPath) as! AttachmentPickerCell
            let totalCount = existingAttachments.count + attachments.count
            let actionTitle = totalCount == 0 ? "Belge Ekle" : "\(totalCount) Belge • Yeni Ekle"
            cell.configure(title: "İşleme bağlı belgeler", actionTitle: actionTitle, symbol: totalCount == 0 ? "paperclip" : "doc.on.doc.fill") { [weak self] in
                self?.addAttachment()
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch tableSections[indexPath.section] {
        case .lineItems:
            indexPath.row == lineItems.count ? editLineItem(nil) : editLineItem(indexPath.row)
        case .fields:
            if field(at: indexPath) == .category { chooseCategory() }
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .lineItems = tableSections[indexPath.section], indexPath.row < lineItems.count else { return nil }
        return UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in
                self?.lineItems.remove(at: indexPath.row)
                if let section = self?.lineItemsSectionIndex { self?.tableView.reloadSections(IndexSet(integer: section), with: .automatic) }
                done(true)
            }
        ])
    }

    private var categoryTitle: String {
        switch type { case .expense: "Masraf türü"; case .insurance: "Sigorta türü"; case .inspection: "Kontrol türü"; default: "Kategori" }
    }

    private func categories() -> [String] {
        switch type {
        case .expense: ["Arıza / Sanayi", "Otopark", "Otoyol", "Yıkama", "Aksesuar", "Vergi", "Ceza", "Çekici", "Ekspertiz", "Diğer"]
        case .insurance: ["Zorunlu trafik sigortası", "Kasko", "Diğer"]
        case .inspection: ["Araç muayenesi", "Egzoz ölçümü", "Ekspertiz", "Servis kontrolü", "Diğer"]
        default: []
        }
    }

    private func chooseCategory() {
        let values = categories()
        presentSelectionSheet(
            title: categoryTitle,
            options: values.map { SelectionSheetOption(title: $0, symbolName: "tag.fill") },
            selectedIndex: values.firstIndex(of: category)
        ) { [weak self] index in
            guard values.indices.contains(index) else { return }
            self?.category = values[index]
            if let path = self?.indexPath(for: .category) { self?.tableView.reloadRows(at: [path], with: .automatic) }
        }
    }

    private func textData(for field: Field) -> (title: String, value: String, placeholder: String, capitalization: UITextAutocapitalizationType) {
        switch field {
        case .title: (type == .expense ? "Açıklama" : "Başlık", recordTitle, type == .expense ? "Masrafı kısaca açıklayın" : "Örn. Periyodik bakım", .sentences)
        case .vendor: (type == .fuel ? "İstasyon" : type == .insurance ? "Şirket" : type == .maintenance ? "Servis" : "İşletme", vendor, "İşletme adı · isteğe bağlı", .words)
        case .policyNumber: ("Poliçe numarası", policyNumber, "Poliçe numarası · isteğe bağlı", .allCharacters)
        case .outcome: ("Sonuç", outcome, "Örn. Muayeneden geçti", .sentences)
        default: ("", "", "", .sentences)
        }
    }

    private func setText(_ value: String, field: Field) {
        switch field { case .title: recordTitle = value; case .vendor: vendor = value; case .policyNumber: policyNumber = value; case .outcome: outcome = value; default: break }
    }

    private func dateTitle(for field: Field) -> String {
        switch field { case .date: "İşlem tarihi"; case .startDate: "Başlangıç tarihi"; case .endDate: "Bitiş tarihi"; case .validityDate: "Geçerlilik tarihi"; case .reminderDate: "Sonraki bakım tarihi"; default: "Tarih" }
    }

    private func dateValue(for field: Field) -> Date? {
        switch field { case .date: date; case .startDate: startDate; case .endDate: endDate; case .validityDate: validityDate; case .reminderDate: reminderDate; default: nil }
    }

    private func setDate(_ value: Date, field: Field) {
        switch field { case .date: date = value; case .startDate: startDate = value; case .endDate: endDate = value; case .validityDate: validityDate = value; case .reminderDate: reminderDate = value; default: break }
    }

    private func numberTitle(for field: Field) -> String {
        switch field { case .odometer: "Kilometre"; case .amount: "Toplam tutar"; case .liters: "Yakıt miktarı"; case .unitPrice: "Litre fiyatı"; case .reminderMileage: "Sonraki bakım kilometresi"; default: "" }
    }

    private func numberPlaceholder(for field: Field) -> String {
        switch field { case .odometer, .reminderMileage: "0"; case .amount: "0,00"; case .liters: "0,0"; case .unitPrice: "0,00"; default: "" }
    }

    private func numberSuffix(for field: Field) -> String? {
        switch field { case .odometer, .reminderMileage: "km"; case .amount: "₺"; case .liters: "L"; case .unitPrice: "₺/L"; default: nil }
    }

    private func numberText(for field: Field) -> String {
        switch field { case .odometer: odometer.map(String.init) ?? ""; case .amount: amount.map(String.init(describing:)) ?? ""; case .liters: liters.map(String.init(describing:)) ?? ""; case .unitPrice: unitPrice.map(String.init(describing:)) ?? ""; case .reminderMileage: reminderMileage.map(String.init) ?? ""; default: "" }
    }

    private func decimal(_ text: String) -> Decimal? {
        Decimal(string: text.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    private func setNumber(_ text: String, field: Field) {
        switch field { case .odometer: odometer = Int64(text); case .amount: amount = decimal(text); case .liters: liters = decimal(text); case .unitPrice: unitPrice = decimal(text); case .reminderMileage: reminderMileage = Int64(text); default: break }
        if type == .fuel {
            let values = CalculateFuelValuesUseCase().execute(liters: liters, unitPrice: unitPrice, total: amount)
            liters = values.0
            unitPrice = values.1
            amount = values.2
            if field != .amount, let path = indexPath(for: .amount), let cell = tableView.cellForRow(at: path) as? DecimalInputCell {
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
            guard let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }
            let item = RecordLineItem(id: index.map { self.lineItems[$0].id } ?? UUID(), recordID: self.recordID, name: name, category: alert.textFields?[1].text, sortOrder: index ?? self.lineItems.count)
            if let index { self.lineItems[index] = item } else { self.lineItems.append(item) }
            if let section = self.lineItemsSectionIndex { self.tableView.reloadSections(IndexSet(integer: section), with: .automatic) }
        })
        present(alert, animated: true)
    }

    private func addAttachment() {
        var sources: [AttachmentSource] = [.files, .photos]
        if VNDocumentCameraViewController.isSupported { sources.append(.scanner) }
        presentSelectionSheet(
            title: "Belge Ekle",
            message: "Belgenin kaynağını seçin.",
            options: sources.map(\.option)
        ) { [weak self] index in
            guard sources.indices.contains(index) else { return }
            switch sources[index] {
            case .files: self?.pickFile()
            case .photos: self?.pickPhoto()
            case .scanner: self?.scanDocument()
            }
        }
    }

    private func pickFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    private func pickPhoto() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 5
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func scanDocument() {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        present(scanner, animated: true)
    }

    private func reloadAttachmentField() {
        guard let path = indexPath(for: .attachment) else { return }
        tableView.reloadRows(at: [path], with: .automatic)
    }

    private func updateSaveButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !isLoadingExistingContent && pendingPhotoLoads == 0 && !isSaving
    }

    @objc private func save() {
        view.endEditing(true)
        let defaultTitle = type.displayName
        let id = recordID
        let normalizedItems = lineItems.enumerated().map { index, item in
            RecordLineItem(id: item.id, recordID: id, name: item.name, category: item.category, brand: item.brand, partNumber: item.partNumber, amount: item.amount, warrantyEndDate: item.warrantyEndDate, notes: item.notes, sortOrder: index)
        }
        let record = VehicleRecord(
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
        isSaving = true
        updateSaveButtonState()
        Task {
            do {
                if existing == nil { try await CreateRecordUseCase(recordRepository: recordRepository, vehicleRepository: vehicleRepository).execute(record, lineItems: normalizedItems) }
                else { try await UpdateRecordUseCase(recordRepository: recordRepository, vehicleRepository: vehicleRepository).execute(record, lineItems: normalizedItems) }
                while let attachment = attachments.first {
                    let document = try await AttachDocumentUseCase(repository: documentRepository, storage: storage).execute(data: attachment.data, vehicleID: vehicle.id, recordID: id, type: attachment.type, displayName: attachment.name, mimeType: attachment.mimeType, fileExtension: attachment.fileExtension)
                    attachments.removeFirst()
                    existingAttachments.append(document)
                }
                let dueDate = reminderDate ?? (type == .insurance ? endDate : type == .inspection ? validityDate : nil)
                if dueDate != nil || reminderMileage != nil {
                    let reminder = Reminder(id: reminderID, vehicleID: vehicle.id, recordID: id, title: "\(record.title) zamanı", dueDate: dueDate, dueMileage: reminderMileage, notificationIdentifier: reminderID.uuidString)
                    try await CreateReminderUseCase(repository: reminderRepository, notificationService: notificationService).execute(reminder)
                }
                onSaved?(record)
            } catch {
                isSaving = false
                updateSaveButtonState()
                reloadAttachmentField()
                presentError(error)
            }
        }
    }

    @objc private func cancel() { dismiss(animated: true) }
}

extension RecordEditorViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                attachments.append(PendingAttachment(data: data, name: url.lastPathComponent, mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", fileExtension: url.pathExtension, type: documentType))
            }
        }
        reloadAttachmentField()
    }
}

extension RecordEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        let loadableResults = results.filter { $0.itemProvider.canLoadObject(ofClass: UIImage.self) }
        pendingPhotoLoads += loadableResults.count
        updateSaveButtonState()
        for result in loadableResults {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let data = (image as? UIImage)?.jpegData(compressionQuality: 0.86) {
                        self.attachments.append(PendingAttachment(data: data, name: "Belge.jpg", mimeType: "image/jpeg", fileExtension: "jpg", type: self.documentType))
                        self.reloadAttachmentField()
                    }
                    self.pendingPhotoLoads = max(0, self.pendingPhotoLoads - 1)
                    self.updateSaveButtonState()
                }
            }
        }
    }
}

extension RecordEditorViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        for index in 0..<scan.pageCount where index < 10 {
            if let data = scan.imageOfPage(at: index).jpegData(compressionQuality: 0.86) {
                attachments.append(PendingAttachment(data: data, name: "Tarama-\(index + 1).jpg", mimeType: "image/jpeg", fileExtension: "jpg", type: documentType))
            }
        }
        reloadAttachmentField()
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { controller.dismiss(animated: true) }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { controller.dismiss(animated: true); presentError(error) }
}

private extension RecordEditorViewController {
    var documentType: DocumentType {
        switch type { case .maintenance: .serviceInvoice; case .fuel: .fuelReceipt; case .insurance: .insurancePolicy; case .inspection: .inspectionDocument; default: .other }
    }
}
