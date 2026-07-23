//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class TimelineViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var viewModel: TimelineViewModel!
    var onAdd: (() -> Void)?
    var onRecord: ((VehicleRecord) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerContainer = UIView()
    private let pageTitleLabel = UILabel()
    private let filterHeaderView = TimelineFilterHeaderView.instantiate()
    private let addButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItems = nil
        view.backgroundColor = AppTheme.backgroundColor

        configureTableView()
        configureFilterHeader()
        configureAddButton()

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

    private func configureTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "TimelineRecordCell", bundle: .main), forCellReuseIdentifier: TimelineRecordCell.reuseIdentifier)
        tableView.backgroundColor = AppTheme.backgroundColor
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 108
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset.bottom = 88
        tableView.verticalScrollIndicatorInsets.bottom = 88
        tableView.sectionHeaderTopPadding = 0
        tableView.accessibilityIdentifier = "timeline.list"

        view.addSubview(tableView)
        tableView.pinToEdges(of: view)
    }

    private func configureFilterHeader() {
        pageTitleLabel.text = "Geçmiş"
        pageTitleLabel.font = AppTheme.font(.title1, weight: .bold)
        pageTitleLabel.textColor = AppTheme.primaryTextColor
        pageTitleLabel.textAlignment = .left
        pageTitleLabel.adjustsFontForContentSizeCategory = true
        pageTitleLabel.accessibilityTraits = .header

        filterHeaderView.onSearchTextChanged = { [weak self] query in
            self?.viewModel.query = query
        }
        filterHeaderView.onFilterSelected = { [weak self] type in
            self?.viewModel.selectFilter(type)
        }
        headerContainer.addSubview(pageTitleLabel)
        headerContainer.addSubview(filterHeaderView)
        pageTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        filterHeaderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageTitleLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            pageTitleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: AppTheme.Metrics.horizontalMargin),
            pageTitleLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -AppTheme.Metrics.horizontalMargin),
            pageTitleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),
            filterHeaderView.topAnchor.constraint(equalTo: pageTitleLabel.bottomAnchor, constant: 4),
            filterHeaderView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            filterHeaderView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            filterHeaderView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor)
        ])
        tableView.tableHeaderView = headerContainer
        updateFilterHeader()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: TimelineViewController, _) in
            controller.tableView.updateTableHeaderHeightIfNeeded()
        }
    }

    private func configureAddButton() {
        addButton.configuration = AppTheme.floatingButtonConfiguration()
        addButton.accessibilityLabel = "Yeni kayıt ekle"
        addButton.accessibilityHint = "Kayıt türü seçimini açar"
        addButton.accessibilityIdentifier = "timeline.add"
        addButton.layer.shadowColor = UIColor.black.cgColor
        addButton.layer.shadowOpacity = 0.2
        addButton.layer.shadowRadius = 10
        addButton.layer.shadowOffset = CGSize(width: 0, height: 5)
        addButton.addTarget(self, action: #selector(add), for: .touchUpInside)

        view.addSubview(addButton)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            addButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            addButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            addButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int { viewModel.sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.sections[section].records.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = TimelineMonthHeaderView()
        header.configure(title: viewModel.sections[section].title)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 38 }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 6 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let records = viewModel.sections[indexPath.section].records
        let record = records[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: TimelineRecordCell.reuseIdentifier,
            for: indexPath
        ) as? TimelineRecordCell else {
            return UITableViewCell()
        }
        cell.configure(
            record: record,
            hasDocument: viewModel.recordIDsWithDocuments.contains(record.id),
            isFirst: indexPath.row == 0,
            isLast: indexPath.row == records.count - 1
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onRecord?(viewModel.sections[indexPath.section].records[indexPath.row])
    }

    private func render() {
        updateFilterHeader()
        tableView.reloadData()
        let hasActiveFilter = !viewModel.query.isEmpty || viewModel.selectedFilter != nil

        let emptyState = EmptyStateView(
            symbol: "clock.arrow.circlepath",
            title: hasActiveFilter ? "Kayıt bulunamadı" : "Henüz kayıt yok",
            message: hasActiveFilter
                ? "Arama metnini veya kayıt türü filtresini değiştirin."
                : "Bakım, yakıt veya masraf ekleyerek aracınızın geçmişini oluşturmaya başlayın.",
            actionTitle: hasActiveFilter ? nil : "İlk Kaydı Ekle"
        ) { [weak self] in self?.onAdd?() }
        tableView.showEmptyState(emptyState, when: viewModel.sections.isEmpty)
    }

    private func updateFilterHeader() {
        filterHeaderView.configure(
            types: RecordType.timelineTypes,
            selectedType: viewModel?.selectedFilter
        )
    }

    @objc private func add() { onAdd?() }
    @objc private func reload() { Task { await viewModel.load() } }
}
