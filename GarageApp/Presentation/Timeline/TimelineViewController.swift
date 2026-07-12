//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class TimelineViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    var viewModel: TimelineViewModel!
    var onAdd: (() -> Void)?; var onRecord: ((VehicleRecord) -> Void)?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad(); title = "Geçmiş"; view.backgroundColor = UIColor(named: "AppBackground")
        view.subviews.forEach { $0.removeFromSuperview() }
        tableView.dataSource = self; tableView.delegate = self; tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Record")
        view.addSubview(tableView); tableView.pinToEdges(of: view)
        searchController.searchResultsUpdater = self; searchController.searchBar.placeholder = "Kayıtlarda ara"; navigationItem.searchController = searchController
        navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add)), UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"), menu: filterMenu())]
        viewModel.onChange = { [weak self] in self?.tableView.reloadData(); self?.navigationItem.rightBarButtonItems?.last?.menu = self?.filterMenu() }
        viewModel.onError = { [weak self] in self?.presentError($0) }
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil)
        Task { await viewModel.load() }
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    private func filterMenu() -> UIMenu {
        UIMenu(title: "Kayıt Türleri", options: .displayInline, children: RecordType.allCases.map { type in
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Record", for: indexPath); var content = cell.defaultContentConfiguration(); content.text = record.title
        var details = [record.recordType.displayName, AppFormatters.date.string(from: record.eventDate)]; if let km = record.odometer { details.append("\(km) km") }; if let amount = record.totalAmount { details.append(AppFormatters.currency.string(from: amount as NSDecimalNumber) ?? "") }; if viewModel.recordIDsWithDocuments.contains(record.id) { details.append("Belge") }
        content.secondaryText = details.joined(separator: " • "); content.image = UIImage(systemName: record.recordType.symbolName); content.imageProperties.tintColor = record.recordType.tintColor; cell.contentConfiguration = content; cell.accessoryType = .disclosureIndicator; return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { tableView.deselectRow(at: indexPath, animated: true); onRecord?(viewModel.sections[indexPath.section].records[indexPath.row]) }
    func updateSearchResults(for searchController: UISearchController) { viewModel.query = searchController.searchBar.text ?? "" }
    @objc private func add() { onAdd?() }
    @objc private func reload() { Task { await viewModel.load() } }
}

final class RecordDetailViewController: UITableViewController {
    var onEdit: (() -> Void)?; var onDelete: (() -> Void)?
    private let record: VehicleRecord; private let lineItems: [RecordLineItem]
    init(record: VehicleRecord, lineItems: [RecordLineItem]) { self.record = record; self.lineItems = lineItems; super.init(style: .insetGrouped) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() { super.viewDidLoad(); title = record.recordType.displayName; navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Düzenle", style: .plain, target: self, action: #selector(edit)); tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Detail") }
    override func numberOfSections(in tableView: UITableView) -> Int { lineItems.isEmpty ? 2 : 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { if section == 0 { return details.count }; if section == 1 { return lineItems.isEmpty ? 1 : lineItems.count }; return 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 0 ? "Kayıt" : (section == 1 && !lineItems.isEmpty ? "İşlem Kalemleri" : nil) }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Detail", for: indexPath); var content = cell.defaultContentConfiguration()
        if indexPath.section == 0 { let detail = details[indexPath.row]; content.text = detail.0; content.secondaryText = detail.1 }
        else if !lineItems.isEmpty && indexPath.section == 1 { let item = lineItems[indexPath.row]; content.text = item.name; content.secondaryText = item.category }
        else { content.text = "Kaydı Sil"; content.textProperties.color = .systemRed; content.textProperties.alignment = .center }
        cell.contentConfiguration = content; return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { if (lineItems.isEmpty && indexPath.section == 1) || indexPath.section == 2 { onDelete?() } }
    private var details: [(String, String)] {
        var result = [("Başlık", record.title), ("Tarih", AppFormatters.date.string(from: record.eventDate))]
        if let vendor = record.vendorName { result.append(("İşletme / Servis", vendor)) }; if let km = record.odometer { result.append(("Kilometre", "\(km) km")) }; if let amount = record.totalAmount { result.append(("Tutar", AppFormatters.currency.string(from: amount as NSDecimalNumber) ?? "")) }; if let notes = record.notes { result.append(("Notlar", notes)) }; return result
    }
    @objc private func edit() { onEdit?() }
}
