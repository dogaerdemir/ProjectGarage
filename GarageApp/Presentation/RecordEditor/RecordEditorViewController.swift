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
        case type
        case fields(FormSection)
        case lineItems
    }

    private enum Field: Hashable {
        case title, date, odometer, amount, vendor, notes, category, liters, unitPrice, fullTank
        case policyNumber, startDate, endDate, validityDate, outcome
        case createReminder, useReminderDate, reminderDate, useReminderMileage, reminderMileage, attachment
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
    private let recordCreatedAt: Date
    private let reminderID = UUID()
    private var lineItems: [RecordLineItem] = []
    private var attachments: [PendingAttachment] = []
    private var existingAttachments: [GarageDocument] = []
    private var isLoadingExistingContent = false
    private var pendingPhotoLoads = 0
    private var pendingFileImports = 0
    private var isSaving = false
    private var persistedRecordUpdatedAt: Date?

    private var type: RecordType
    private var recordTitle = "", vendor = "", notes = "", category = "", policyNumber = "", outcome = ""
    private var date = Date.now, startDate = Date.now, endDate: Date?, validityDate: Date?
    private var odometer: Int64?, amount: Decimal?, liters: Decimal?, unitPrice: Decimal?, fullTank = false
    private var reminderDate: Date?, reminderMileage: Int64?
    private var usesReminderDate = false, usesReminderMileage = false
    private var showsReminderOptions = false

    init(
        vehicle: Vehicle, type: RecordType, existing: VehicleRecord? = nil,
        initialVendorName: String? = nil,
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
        persistedRecordUpdatedAt = existing?.updatedAt
        recordID = existing?.id ?? UUID()
        recordCreatedAt = existing?.createdAt ?? .now
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
            vendor = initialVendorName ?? ""
            odometer = vehicle.currentMileage
            if type == .insurance { endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) }
            if type == .inspection { validityDate = Calendar.current.date(byAdding: .year, value: 2, to: .now) }
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateNavigationTitle()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Vazgeç", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kaydet", style: .done, target: self, action: #selector(save))
        tableView.register(
            UINib(nibName: "RecordEditorCompactRowCell", bundle: .main),
            forCellReuseIdentifier: "RecordEditorCompactRowCell"
        )
        tableView.register(
            UINib(nibName: "RecordEditorCompactNotesCell", bundle: .main),
            forCellReuseIdentifier: "RecordEditorCompactNotesCell"
        )
        AppTheme.styleForm(tableView)
        configureCompactAppearance()
        configureSheetAppearance()
        isLoadingExistingContent = existing != nil
        updateSaveButtonState()
        loadExistingContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureSheetAppearance()
    }

    private func configureCompactAppearance() {
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = AppTheme.borderColor
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 58
        tableView.sectionHeaderTopPadding = AppTheme.Spacing.xSmall
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: AppTheme.Spacing.medium, right: 0)
        tableView.keyboardDismissMode = .interactive
    }

    private func configureSheetAppearance() {
        guard let sheet = navigationController?.sheetPresentationController else { return }
        sheet.detents = [.large()]
        sheet.selectedDetentIdentifier = .large
        sheet.prefersGrabberVisible = false
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.preferredCornerRadius = 18
    }

    private func updateNavigationTitle() {
        title = switch type {
        case .maintenance: "Bakım Kaydı"
        case .fuel: "Yakıt Kaydı"
        case .expense: "Masraf Kaydı"
        case .insurance: "Sigorta Kaydı"
        case .inspection: "Muayene Kaydı"
        case .mileage: "Kilometre Güncelle"
        case .note: "Not Kaydı"
        }
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
            var reminderFields: [Field] = [.createReminder]
            if showsReminderOptions {
                reminderFields.append(.useReminderDate)
                if usesReminderDate { reminderFields.append(.reminderDate) }
                reminderFields.append(.useReminderMileage)
                if usesReminderMileage { reminderFields.append(.reminderMileage) }
            }
            return [
                FormSection(title: "Bilgiler", fields: [.title, .date, .odometer, .amount, .vendor]),
                FormSection(title: "Belge", fields: [.attachment]),
                FormSection(title: "Hatırlatma", fields: reminderFields),
                FormSection(title: "Notlar", fields: [.notes])
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
        var result: [TableSection] = [.type]
        result.append(contentsOf: formSections.map(TableSection.fields))
        if type == .maintenance { result.insert(.lineItems, at: min(2, result.count)) }
        return result
    }

    private var lineItemsSectionIndex: Int? {
        tableSections.firstIndex { if case .lineItems = $0 { return true }; return false }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { tableSections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableSections[section] {
        case .type: 1
        case let .fields(section): section.fields.count
        case .lineItems: lineItems.count + 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch tableSections[section] {
        case .type: "Tür"
        case let .fields(section): section.title
        case .lineItems: "Bakım Kalemleri"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if case let .fields(section) = tableSections[section] { return section.footer }
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        34
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if case let .fields(section) = tableSections[section], section.footer != nil {
            return UITableView.automaticDimension
        }
        return .leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = AppTheme.font(.subheadline, weight: .medium)
        header.textLabel?.textColor = AppTheme.secondaryTextColor
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else { return }
        footer.textLabel?.font = AppTheme.font(.footnote)
        footer.textLabel?.textColor = AppTheme.secondaryTextColor
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
        if case .type = tableSections[indexPath.section] {
            let cell = compactRowCell(tableView, at: indexPath)
            let canChangeType = existing == nil && type != .mileage
            cell.configureSelection(
                title: type.selectionDisplayName,
                value: nil,
                placeholder: "",
                symbol: type.symbolName,
                showsChevron: canChangeType,
                enabled: canChangeType
            )
            return cell
        }

        if case .lineItems = tableSections[indexPath.section] {
            let cell = compactRowCell(tableView, at: indexPath)
            if indexPath.row == lineItems.count {
                cell.configureAction(title: "Kalem Ekle", symbol: "plus")
                return cell
            }
            let item = lineItems[indexPath.row]
            cell.configureSelection(
                title: item.name,
                value: item.category,
                placeholder: "Düzenle",
                showsChevron: true
            )
            return cell
        }

        guard let field = field(at: indexPath) else { return UITableViewCell() }
        switch field {
        case .title, .vendor, .policyNumber, .outcome:
            let cell = compactRowCell(tableView, at: indexPath)
            let data = textData(for: field)
            cell.configureText(title: data.title, value: data.value, placeholder: data.placeholder, autocapitalizationType: data.capitalization) { [weak self] value in
                self?.setText(value, field: field)
            }
            return cell

        case .category:
            let cell = compactRowCell(tableView, at: indexPath)
            cell.configureSelection(title: categoryTitle, value: category.isEmpty ? nil : category)
            return cell

        case .date, .startDate, .endDate, .validityDate, .reminderDate:
            let cell = compactRowCell(tableView, at: indexPath)
            cell.configureDate(title: dateTitle(for: field), date: dateValue(for: field) ?? .now) { [weak self] value in
                self?.setDate(value, field: field)
            }
            return cell

        case .odometer, .amount, .liters, .unitPrice, .reminderMileage:
            let cell = compactRowCell(tableView, at: indexPath)
            let isMileage = field == .odometer || field == .reminderMileage
            cell.configureText(
                title: numberTitle(for: field),
                value: numberText(for: field),
                placeholder: numberPlaceholder(for: field),
                keyboardType: isMileage ? .numberPad : .decimalPad,
                suffix: numberSuffix(for: field)
            ) { [weak self] value in self?.setNumber(value, field: field) }
            return cell

        case .fullTank:
            let cell = compactRowCell(tableView, at: indexPath)
            cell.configureToggle(title: "Tam depo", isOn: fullTank) { [weak self] in self?.fullTank = $0 }
            return cell

        case .createReminder:
            let cell = compactRowCell(tableView, at: indexPath)
            cell.configureToggle(title: "Hatırlatma Oluştur", isOn: showsReminderOptions) { [weak self] enabled in
                guard let self else { return }
                showsReminderOptions = enabled
                if enabled {
                    usesReminderDate = true
                    reminderDate = reminderDate ?? Calendar.current.date(byAdding: .month, value: 6, to: .now)
                } else {
                    usesReminderDate = false
                    reminderDate = nil
                    usesReminderMileage = false
                    reminderMileage = nil
                }
                self.tableView.reloadData()
            }
            return cell

        case .useReminderDate:
            let cell = compactRowCell(tableView, at: indexPath)
            cell.configureToggle(title: "Tarih Hedefi", isOn: usesReminderDate) { [weak self] enabled in
                self?.usesReminderDate = enabled
                self?.reminderDate = enabled ? (self?.reminderDate ?? Calendar.current.date(byAdding: .month, value: 6, to: .now)) : nil
                self?.tableView.reloadData()
            }
            return cell

        case .useReminderMileage:
            let cell = compactRowCell(tableView, at: indexPath)
            cell.configureToggle(title: "Kilometre Hedefi", isOn: usesReminderMileage) { [weak self] enabled in
                self?.usesReminderMileage = enabled
                if !enabled { self?.reminderMileage = nil }
                self?.tableView.reloadData()
            }
            return cell

        case .notes:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "RecordEditorCompactNotesCell",
                for: indexPath
            ) as! RecordEditorCompactNotesCell
            cell.configure(title: "Not · isteğe bağlı", text: notes, placeholder: "İşlemle ilgili not ekleyin") { [weak self] in
                self?.notes = $0
            }
            return cell

        case .attachment:
            let cell = compactRowCell(tableView, at: indexPath)
            let documents = existingAttachments.map { ($0.displayName, $0.fileSize) }
                + attachments.map { ($0.name, Int64($0.data.count)) }
            if let first = documents.first, documents.count == 1 {
                cell.configureSelection(
                    title: first.0,
                    value: ByteCountFormatter.string(fromByteCount: first.1, countStyle: .file),
                    symbol: "doc.fill"
                )
            } else if documents.count > 1 {
                cell.configureSelection(
                    title: "\(documents.count) Belge",
                    value: "Yeni belge ekle",
                    symbol: "doc.on.doc.fill"
                )
            } else {
                cell.configureAction(
                    title: "Belge Ekle",
                    symbol: "paperclip",
                    subtitle: "Dosya, fotoğraf veya tarama"
                )
            }
            return cell
        }
    }

    private func compactRowCell(_ tableView: UITableView, at indexPath: IndexPath) -> RecordEditorCompactRowCell {
        tableView.dequeueReusableCell(withIdentifier: "RecordEditorCompactRowCell", for: indexPath) as! RecordEditorCompactRowCell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch tableSections[indexPath.section] {
        case .type:
            chooseRecordType()
        case .lineItems:
            indexPath.row == lineItems.count ? editLineItem(nil) : editLineItem(indexPath.row)
        case .fields:
            if field(at: indexPath) == .category { chooseCategory() }
            if field(at: indexPath) == .attachment { addAttachment() }
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

    private func chooseRecordType() {
        guard existing == nil, type != .mileage else { return }
        let values = RecordType.timelineTypes
        presentSelectionSheet(
            title: "Kayıt Türü",
            options: values.map { SelectionSheetOption(title: $0.selectionDisplayName, symbolName: $0.symbolName) },
            selectedIndex: values.firstIndex(of: type)
        ) { [weak self] index in
            guard let self, values.indices.contains(index), values[index] != type else { return }
            let previousType = type
            type = values[index]
            category = ""
            if previousType == .maintenance, type != .maintenance {
                lineItems.removeAll()
                showsReminderOptions = false
                usesReminderDate = false
                reminderDate = nil
                usesReminderMileage = false
                reminderMileage = nil
            }
            if type == .insurance, endDate == nil {
                endDate = Calendar.current.date(byAdding: .year, value: 1, to: .now)
            }
            if type == .inspection, validityDate == nil {
                validityDate = Calendar.current.date(byAdding: .year, value: 2, to: .now)
            }
            updateNavigationTitle()
            tableView.reloadData()
        }
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
            if field != .amount,
               let path = indexPath(for: .amount),
               let cell = tableView.cellForRow(at: path) as? RecordEditorCompactRowCell {
                cell.updateTextValue(amount.map(String.init(describing:)) ?? "")
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
        navigationItem.rightBarButtonItem?.isEnabled = !isLoadingExistingContent
            && pendingPhotoLoads == 0
            && pendingFileImports == 0
            && !isSaving
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
            outcome: outcome.isEmpty ? nil : outcome, createdAt: recordCreatedAt, updatedAt: .now
        )
        isSaving = true
        updateSaveButtonState()
        Task {
            do {
                if let persistedRecordUpdatedAt {
                    try await UpdateRecordUseCase(
                        recordRepository: recordRepository,
                        vehicleRepository: vehicleRepository
                    ).execute(
                        record,
                        lineItems: normalizedItems,
                        expectedUpdatedAt: persistedRecordUpdatedAt
                    )
                } else {
                    try await CreateRecordUseCase(
                        recordRepository: recordRepository,
                        vehicleRepository: vehicleRepository
                    ).execute(record, lineItems: normalizedItems)
                }
                self.persistedRecordUpdatedAt = record.updatedAt
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
        guard !urls.isEmpty else { return }
        let attachmentType = documentType
        pendingFileImports += 1
        updateSaveButtonState()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = RecordAttachmentImporter.load(urls: urls)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                pendingFileImports = max(0, pendingFileImports - 1)
                attachments.append(contentsOf: result.attachments.map {
                    PendingAttachment(
                        data: $0.data,
                        name: $0.name,
                        mimeType: $0.mimeType,
                        fileExtension: $0.fileExtension,
                        type: attachmentType
                    )
                })
                reloadAttachmentField()
                updateSaveButtonState()
                if !result.failureMessages.isEmpty {
                    presentAttachmentImportFailures(result.failureMessages)
                }
            }
        }
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
    func presentAttachmentImportFailures(_ messages: [String]) {
        let visibleMessages = messages.prefix(3)
        var message = visibleMessages.joined(separator: "\n\n")
        if messages.count > visibleMessages.count {
            message += "\n\n\(messages.count - visibleMessages.count) dosya daha eklenemedi."
        }
        let alert = UIAlertController(
            title: messages.count == 1 ? "Belge Eklenemedi" : "Bazı Belgeler Eklenemedi",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }

    var documentType: DocumentType {
        switch type { case .maintenance: .serviceInvoice; case .fuel: .fuelReceipt; case .insurance: .insurancePolicy; case .inspection: .inspectionDocument; default: .other }
    }
}

private struct RecordAttachmentImportPayload: Sendable {
    let data: Data
    let name: String
    let mimeType: String
    let fileExtension: String
}

private struct RecordAttachmentImportResult: Sendable {
    let attachments: [RecordAttachmentImportPayload]
    let failureMessages: [String]
}

private enum RecordAttachmentImporter {
    private enum ImportError: Error {
        case tooLarge
        case unsupportedItem
    }

    private static let readChunkSize = 256 * 1_024

    static func load(urls: [URL]) -> RecordAttachmentImportResult {
        var attachments: [RecordAttachmentImportPayload] = []
        var failureMessages: [String] = []

        for url in urls {
            let name = displayName(for: url)
            do {
                attachments.append(try load(url: url, displayName: name))
            } catch ImportError.tooLarge {
                failureMessages.append(
                    "“\(name)” 20 MB sınırını aşıyor. Dosyayı küçültüp yeniden seçin."
                )
            } catch ImportError.unsupportedItem {
                failureMessages.append("“\(name)” desteklenen bir dosya değil.")
            } catch {
                failureMessages.append(
                    "“\(name)” okunamadı. Dosyanın cihazda kullanılabilir olduğundan emin olup yeniden deneyin."
                )
            }
        }

        return RecordAttachmentImportResult(
            attachments: attachments,
            failureMessages: failureMessages
        )
    }

    private static func load(url: URL, displayName: String) throws -> RecordAttachmentImportPayload {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard resourceValues.isRegularFile != false else {
            throw ImportError.unsupportedItem
        }
        if let fileSize = resourceValues.fileSize,
           fileSize > AssetStorageLimits.maximumDataSize {
            throw ImportError.tooLarge
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var data = Data()
        if let fileSize = resourceValues.fileSize {
            data.reserveCapacity(min(max(0, fileSize), AssetStorageLimits.maximumDataSize))
        }

        while true {
            let remainingBytes = AssetStorageLimits.maximumDataSize - data.count
            let nextReadSize = min(readChunkSize, remainingBytes + 1)
            let chunk = try handle.read(upToCount: nextReadSize) ?? Data()
            guard !chunk.isEmpty else { break }
            data.append(chunk)
            guard data.count <= AssetStorageLimits.maximumDataSize else {
                throw ImportError.tooLarge
            }
        }

        let fileExtension = url.pathExtension
        return RecordAttachmentImportPayload(
            data: data,
            name: displayName,
            mimeType: UTType(filenameExtension: fileExtension)?.preferredMIMEType
                ?? "application/octet-stream",
            fileExtension: fileExtension
        )
    }

    private static func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Seçilen dosya" : name
    }
}
