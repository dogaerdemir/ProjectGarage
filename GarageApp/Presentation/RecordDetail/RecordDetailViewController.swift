//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

final class RecordDetailViewController: UITableViewController {
    private enum Section {
        case details
        case lineItems
        case documents
        case delete
    }

    var onEdit: ((VehicleRecord) -> Void)?
    var onDelete: (() -> Void)?
    var onDocument: ((GarageDocument) -> Void)?

    private let viewModel: RecordDetailViewModel
    private let heroView = RecordDetailHeroView.instantiate()

    init(viewModel: RecordDetailViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Düzenle", style: .plain, target: self, action: #selector(edit))

        tableView.register(
            UINib(nibName: "RecordDetailRowCell", bundle: .main),
            forCellReuseIdentifier: RecordDetailRowCell.reuseIdentifier
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RecordDetailDeleteCell")
        tableView.backgroundColor = AppTheme.backgroundColor
        tableView.separatorColor = AppTheme.borderColor
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 46
        tableView.sectionHeaderTopPadding = AppTheme.Spacing.medium
        tableView.tableHeaderView = heroView
        tableView.accessibilityIdentifier = "recordDetail.list"

        viewModel.onChange = { [weak self] in self?.render() }
        viewModel.onError = { [weak self] in self?.presentError($0) }
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectedVehicleChanged), name: .selectedVehicleDidChange, object: nil)
        render()
        Task { await viewModel.load() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.updateTableHeaderHeightIfNeeded()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func stopObservingChanges() {
        NotificationCenter.default.removeObserver(self, name: .garageDataDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .selectedVehicleDidChange, object: nil)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .details: details.count
        case .lineItems: viewModel.lineItems.count
        case .documents: viewModel.documents.count
        case .delete: 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .details: "Bilgiler"
        case .lineItems: "İşlem Kalemleri"
        case .documents: "Belgeler"
        case .delete: nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .details:
            let detail = details[indexPath.row]
            let cell = detailRowCell(tableView, indexPath: indexPath)
            cell.configure(key: detail.0, value: detail.1)
            return cell

        case .lineItems:
            let cell = detailRowCell(tableView, indexPath: indexPath)
            cell.configure(lineItem: viewModel.lineItems[indexPath.row])
            return cell

        case .documents:
            let cell = detailRowCell(tableView, indexPath: indexPath)
            cell.configure(document: viewModel.documents[indexPath.row])
            return cell

        case .delete:
            let cell = tableView.dequeueReusableCell(withIdentifier: "RecordDetailDeleteCell", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = "Kaydı Sil"
            content.textProperties.color = AppTheme.dangerColor
            content.textProperties.font = AppTheme.font(.body, weight: .medium)
            content.textProperties.alignment = .center
            cell.backgroundColor = AppTheme.surfaceColor
            cell.contentConfiguration = content
            cell.selectionStyle = .default
            cell.accessibilityLabel = "Kaydı sil"
            cell.accessibilityTraits = .button
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .documents: onDocument?(viewModel.documents[indexPath.row])
        case .delete: onDelete?()
        case .details, .lineItems: break
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            return UITableView.automaticDimension
        }
        return switch sections[indexPath.section] {
        case .documents: 66
        case .details, .lineItems, .delete: 46
        }
    }

    private func detailRowCell(_ tableView: UITableView, indexPath: IndexPath) -> RecordDetailRowCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: RecordDetailRowCell.reuseIdentifier,
            for: indexPath
        ) as? RecordDetailRowCell else {
            preconditionFailure("RecordDetailRowCell.xib could not be loaded")
        }
        return cell
    }

    private var sections: [Section] {
        var result: [Section] = [.details]
        if !viewModel.lineItems.isEmpty { result.append(.lineItems) }
        if !viewModel.documents.isEmpty { result.append(.documents) }
        result.append(.delete)
        return result
    }

    private var details: [(String, String)] {
        guard let record = viewModel.record else { return [] }
        var result = [("Tarih", AppFormatters.date.string(from: record.eventDate))]
        if let odometer = record.odometer { result.append(("Kilometre", RecordVisualStyle.mileage(odometer))) }
        if let vendor = normalized(record.vendorName) { result.append(("İşletme", vendor)) }

        if let liters = record.liters { result.append(("Yakıt Miktarı", "\(decimalText(liters)) L")) }
        if let unitPrice = record.unitPrice { result.append(("Litre Fiyatı", "\(decimalText(unitPrice)) ₺/L")) }
        if let isFullTank = record.isFullTank { result.append(("Dolum", isFullTank ? "Tam depo" : "Kısmi dolum")) }
        if let policyType = normalized(record.policyType) { result.append(("Sigorta / Masraf Türü", policyType)) }
        if let policyNumber = normalized(record.policyNumber) { result.append(("Poliçe Numarası", policyNumber)) }
        if let startDate = record.startDate { result.append(("Başlangıç", AppFormatters.date.string(from: startDate))) }
        if let endDate = record.endDate { result.append(("Bitiş", AppFormatters.date.string(from: endDate))) }
        if let inspectionType = normalized(record.inspectionType) { result.append(("Kontrol Türü", inspectionType)) }
        if let validityDate = record.validityDate { result.append(("Geçerlilik", AppFormatters.date.string(from: validityDate))) }
        if let outcome = normalized(record.outcome) { result.append(("Sonuç", outcome)) }
        if let notes = normalized(record.notes) { result.append(("Notlar", notes)) }
        return result
    }

    private func render() {
        guard let record = viewModel.record else {
            title = "Kayıt Detayı"
            navigationItem.rightBarButtonItem?.isEnabled = false
            tableView.reloadData()
            return
        }
        title = RecordVisualStyle.detailTitle(for: record.recordType)
        navigationItem.rightBarButtonItem?.isEnabled = true
        heroView.configure(record: record)
        tableView.reloadData()
        tableView.updateTableHeaderHeightIfNeeded()
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private func decimalText(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? String(describing: value)
    }

    @objc private func edit() {
        guard let record = viewModel.record else { return }
        onEdit?(record)
    }

    @objc private func reload() { Task { await viewModel.load() } }

    @objc private func selectedVehicleChanged() {
        stopObservingChanges()
        navigationController?.popViewController(animated: true)
    }
}
