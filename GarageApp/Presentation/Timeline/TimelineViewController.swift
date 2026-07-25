//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class TimelineViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var viewModel: TimelineViewModel!
    var onAdd: (() -> Void)?
    var onRecord: ((VehicleRecord) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let pageTitleLabel = UILabel()
    private let filterHeaderView = TimelineFilterHeaderView.instantiate()
    private let addButton = UIButton(type: .system)
    private weak var emptyStateView: EmptyStateView?

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

    private func configureTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "TimelineRecordCell", bundle: .main), forCellReuseIdentifier: TimelineRecordCell.reuseIdentifier)
        tableView.backgroundColor = AppTheme.backgroundColor
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 108
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset.bottom = AppTheme.Metrics.floatingContentBottomInset
        tableView.verticalScrollIndicatorInsets.bottom = AppTheme.Metrics.floatingContentBottomInset
        tableView.sectionHeaderTopPadding = 0
        tableView.accessibilityIdentifier = "timeline.list"

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureFilterHeader() {
        pageTitleLabel.text = "Geçmiş"
        AppTheme.stylePageTitle(pageTitleLabel)

        filterHeaderView.onSearchTextChanged = { [weak self] query in
            self?.viewModel.query = query
        }
        filterHeaderView.onFilterSelected = { [weak self] type in
            self?.viewModel.selectFilter(type)
        }
        view.addSubview(pageTitleLabel)
        view.addSubview(filterHeaderView)
        pageTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        filterHeaderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageTitleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: AppTheme.Metrics.pageTopInset
            ),
            pageTitleLabel.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: AppTheme.Metrics.horizontalMargin
            ),
            pageTitleLabel.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -AppTheme.Metrics.horizontalMargin
            ),
            filterHeaderView.topAnchor.constraint(
                equalTo: pageTitleLabel.bottomAnchor,
                constant: AppTheme.Metrics.pageTitleToSearchSpacing
            ),
            filterHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: filterHeaderView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        updateFilterHeader()
    }

    private func configureAddButton() {
        AppTheme.styleFloatingButton(addButton)
        addButton.accessibilityLabel = "Yeni kayıt ekle"
        addButton.accessibilityHint = "Kayıt türü seçimini açar"
        addButton.accessibilityIdentifier = "timeline.add"
        addButton.addTarget(self, action: #selector(add), for: .touchUpInside)

        view.addSubview(addButton)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            addButton.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -AppTheme.Metrics.floatingButtonTrailingInset
            ),
            addButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -AppTheme.Metrics.floatingButtonBottomInset
            ),
            addButton.widthAnchor.constraint(equalToConstant: AppTheme.Metrics.floatingButtonSize),
            addButton.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.floatingButtonSize)
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
            actionTitle: hasActiveFilter ? nil : "İlk Kaydı Ekle",
            reservedMessageLineCount: 3
        ) { [weak self] in self?.onAdd?() }
        setEmptyState(viewModel.sections.isEmpty ? emptyState : nil)
    }

    private func setEmptyState(_ emptyState: EmptyStateView?) {
        emptyStateView?.removeFromSuperview()
        emptyStateView = nil
        tableView.backgroundView = nil
        guard let emptyState else { return }

        view.insertSubview(emptyState, belowSubview: addButton)
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyState.topAnchor.constraint(equalTo: tableView.topAnchor),
            emptyState.leadingAnchor.constraint(equalTo: pageTitleLabel.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: pageTitleLabel.trailingAnchor),
            emptyState.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        emptyStateView = emptyState
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
