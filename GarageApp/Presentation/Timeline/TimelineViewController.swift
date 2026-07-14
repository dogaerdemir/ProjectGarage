//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class TimelineViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    var viewModel: TimelineViewModel!
    var onAdd: (() -> Void)?; var onRecord: ((VehicleRecord) -> Void)?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchBar = UISearchBar()

    override func viewDidLoad() {
        super.viewDidLoad(); navigationItem.title = nil; navigationItem.largeTitleDisplayMode = .never; view.backgroundColor = AppTheme.backgroundColor
        view.subviews.forEach { $0.removeFromSuperview() }
        tableView.dataSource = self; tableView.delegate = self; tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Record")
        AppTheme.styleList(tableView)
        tableView.sectionHeaderTopPadding = 0
        view.addSubview(tableView); tableView.pinToEdges(of: view)
        searchBar.delegate = self; searchBar.placeholder = "Kayıtlarda ara"; searchBar.searchBarStyle = .minimal; searchBar.autocapitalizationType = .none
        searchBar.accessibilityLabel = "Kayıtlarda ara"
        tableView.tableHeaderView = PageHeaderView(title: "Geçmiş", accessoryView: searchBar)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: TimelineViewController, _) in
            controller.tableView.updateTableHeaderHeightIfNeeded()
        }
        navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add)), UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"), menu: filterMenu())]
        viewModel.onChange = { [weak self] in self?.render() }
        viewModel.onError = { [weak self] in self?.presentError($0) }
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil)
        Task { await viewModel.load() }
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.updateTableHeaderHeightIfNeeded()
    }

    private func filterMenu() -> UIMenu {
        UIMenu(title: "Kayıt Türleri", options: .displayInline, children: RecordType.timelineTypes.map { type in
            UIAction(title: type.displayName, image: UIImage(systemName: type.symbolName), state: viewModel?.selectedTypes.contains(type) == true ? .on : .off) { [weak self] _ in
                guard let self else { return }; if viewModel.selectedTypes.contains(type) { viewModel.selectedTypes.remove(type) } else { viewModel.selectedTypes.insert(type) }
            }
        })
    }
    func numberOfSections(in tableView: UITableView) -> Int { viewModel.sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { viewModel.sections[section].records.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { viewModel.sections[section].title }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let record = viewModel.sections[indexPath.section].records[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Record", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell(); content.text = record.title
        content.textProperties.font = AppTheme.font(.body, weight: .semibold); content.textProperties.color = AppTheme.primaryTextColor
        var details = [record.recordType.displayName, AppFormatters.date.string(from: record.eventDate)]
        if let km = record.odometer { details.append("\(AppFormatters.mileage.string(from: NSNumber(value: km)) ?? String(km)) km") }
        if let amount = record.totalAmount { details.append(AppFormatters.currency.string(from: amount as NSDecimalNumber) ?? "") }
        if viewModel.recordIDsWithDocuments.contains(record.id) { details.append("Belge ekli") }
        content.secondaryText = details.joined(separator: " • "); content.secondaryTextProperties.color = AppTheme.secondaryTextColor
        content.image = UIImage(systemName: record.recordType.symbolName); content.imageProperties.tintColor = record.recordType.tintColor
        cell.contentConfiguration = content; cell.accessoryType = .disclosureIndicator; return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { tableView.deselectRow(at: indexPath, animated: true); onRecord?(viewModel.sections[indexPath.section].records[indexPath.row]) }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { viewModel.query = searchText }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    private func render() {
        tableView.reloadData()
        navigationItem.rightBarButtonItems?.last?.menu = filterMenu()
        let emptyState = EmptyStateView(
            symbol: "clock.arrow.circlepath",
            title: "Henüz kayıt yok",
            message: "Bakım, yakıt, masraf veya kilometre kaydı ekleyerek araç geçmişinizi oluşturun.",
            actionTitle: "İlk Kaydı Ekle"
        ) { [weak self] in self?.onAdd?() }
        tableView.showEmptyState(emptyState, when: viewModel.sections.isEmpty)
    }
    @objc private func add() { onAdd?() }
    @objc private func reload() { Task { await viewModel.load() } }

}

final class RecordDetailViewController: UITableViewController {
    private enum Section {
        case record
        case lineItems
        case documents
        case delete
    }

    var onEdit: ((VehicleRecord) -> Void)?
    var onDelete: (() -> Void)?
    var onDocument: ((GarageDocument) -> Void)?

    private let viewModel: RecordDetailViewModel

    init(viewModel: RecordDetailViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Düzenle", style: .plain, target: self, action: #selector(edit))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Detail")
        tableView.register(UINib(nibName: "KeyValueCell", bundle: .main), forCellReuseIdentifier: "KeyValueCell")
        tableView.register(UINib(nibName: "DocumentListCell", bundle: .main), forCellReuseIdentifier: "DocumentListCell")
        AppTheme.styleList(tableView)
        viewModel.onChange = { [weak self] in self?.render() }
        viewModel.onError = { [weak self] in self?.presentError($0) }
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectedVehicleChanged), name: .selectedVehicleDidChange, object: nil)
        render()
        Task { await viewModel.load() }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func stopObservingChanges() {
        NotificationCenter.default.removeObserver(self, name: .garageDataDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .selectedVehicleDidChange, object: nil)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .record: details.count
        case .lineItems: viewModel.lineItems.count
        case .documents: viewModel.documents.count
        case .delete: 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .record: "Kayıt"
        case .lineItems: "İşlem Kalemleri"
        case .documents: "Belgeler"
        case .delete: nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .record:
            let detail = details[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "KeyValueCell", for: indexPath) as! KeyValueCell
            cell.configure(key: detail.0, value: detail.1)
            return cell
        case .lineItems:
            let item = viewModel.lineItems[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "Detail", for: indexPath)
            var content = UIListContentConfiguration.subtitleCell()
            content.text = item.name
            content.secondaryText = item.category
            content.textProperties.font = AppTheme.font(.body, weight: .medium)
            content.secondaryTextProperties.color = AppTheme.secondaryTextColor
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            return cell
        case .documents:
            let document = viewModel.documents[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "DocumentListCell", for: indexPath) as! DocumentListCell
            cell.configure(document: document)
            return cell
        case .delete:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Detail", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = "Kaydı Sil"
            content.textProperties.color = AppTheme.dangerColor
            content.textProperties.alignment = .center
            cell.selectionStyle = .default
            cell.contentConfiguration = content
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .documents: onDocument?(viewModel.documents[indexPath.row])
        case .delete: onDelete?()
        case .record, .lineItems: break
        }
    }

    private var sections: [Section] {
        var result: [Section] = [.record]
        if !viewModel.lineItems.isEmpty { result.append(.lineItems) }
        if !viewModel.documents.isEmpty { result.append(.documents) }
        result.append(.delete)
        return result
    }

    private var details: [(String, String)] {
        guard let record = viewModel.record else { return [] }
        var result = [("Başlık", record.title), ("Tarih", AppFormatters.date.string(from: record.eventDate))]
        if let vendor = record.vendorName { result.append(("İşletme / Servis", vendor)) }
        if let km = record.odometer { result.append(("Kilometre", "\(AppFormatters.mileage.string(from: NSNumber(value: km)) ?? String(km)) km")) }
        if let amount = record.totalAmount { result.append(("Tutar", AppFormatters.currency.string(from: amount as NSDecimalNumber) ?? "")) }
        if let liters = record.liters { result.append(("Yakıt miktarı", "\(liters) L")) }
        if let unitPrice = record.unitPrice { result.append(("Litre fiyatı", "\(unitPrice) ₺/L")) }
        if let isFullTank = record.isFullTank { result.append(("Dolum", isFullTank ? "Tam depo" : "Kısmi dolum")) }
        if let policyType = record.policyType { result.append(("Sigorta / Masraf türü", policyType)) }
        if let policyNumber = record.policyNumber { result.append(("Poliçe numarası", policyNumber)) }
        if let startDate = record.startDate { result.append(("Başlangıç", AppFormatters.date.string(from: startDate))) }
        if let endDate = record.endDate { result.append(("Bitiş", AppFormatters.date.string(from: endDate))) }
        if let inspectionType = record.inspectionType { result.append(("Kontrol türü", inspectionType)) }
        if let validityDate = record.validityDate { result.append(("Geçerlilik", AppFormatters.date.string(from: validityDate))) }
        if let outcome = record.outcome { result.append(("Sonuç", outcome)) }
        if let notes = record.notes { result.append(("Notlar", notes)) }
        return result
    }

    private func render() {
        title = viewModel.record?.recordType.displayName ?? "Kayıt"
        navigationItem.rightBarButtonItem?.isEnabled = viewModel.record != nil
        tableView.reloadData()
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
