//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class ReminderListViewController: UITableViewController {
    private enum Filter: Int {
        case active
        case completed
    }

    var onAdd: (() -> Void)?
    var onReminder: ((Reminder) -> Void)?

    private let session: AppSession
    private let repository: ReminderRepository
    private let recordRepository: VehicleRecordRepository?
    private let notificationService: NotificationSchedulingService
    private var reminders: [Reminder] = []
    private var linkedRecordTypes: [UUID: RecordType] = [:]
    private var selectedFilter = Filter.active
    private var filterHeaderView: ReminderFilterHeaderView?
    private var loadGeneration = 0

    init(
        session: AppSession,
        repository: ReminderRepository,
        recordRepository: VehicleRecordRepository? = nil,
        notificationService: NotificationSchedulingService
    ) {
        self.session = session
        self.repository = repository
        self.recordRepository = recordRepository
        self.notificationService = notificationService
        super.init(style: .plain)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hatırlatmalar"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)),
            style: .plain,
            target: self,
            action: #selector(add)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Hatırlatma Ekle"
        tableView.register(UINib(nibName: "ReminderCardCell", bundle: .main), forCellReuseIdentifier: "ReminderCardCell")
        AppTheme.styleList(tableView)
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 140
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: AppTheme.Spacing.standard, right: 0)
        tableView.showsVerticalScrollIndicator = false
        configureFilterHeader()
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let filterHeaderView else { return }
        let targetFrame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 64)
        guard filterHeaderView.frame != targetFrame else { return }
        filterHeaderView.frame = targetFrame
        tableView.tableHeaderView = filterHeaderView
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleReminders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reminder = visibleReminders[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ReminderCardCell", for: indexPath) as? ReminderCardCell else {
            return UITableViewCell()
        }
        cell.configure(
            reminder: reminder,
            currentMileage: session.selectedVehicle?.currentMileage ?? 0,
            linkedRecordType: linkedRecordTypes[reminder.id],
            showsDisclosure: onReminder != nil
        )
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onReminder?(visibleReminders[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let reminder = visibleReminders[indexPath.row]
        let complete = UIContextualAction(style: .normal, title: "Tamamla") { [weak self] _, _, done in
            Task { @MainActor [weak self] in
                guard let self else { done(false); return }
                do {
                    try await CompleteReminderUseCase(
                        repository: repository,
                        notificationService: notificationService
                    ).execute(reminder)
                    done(true)
                    reload()
                } catch {
                    done(false)
                    presentError(error)
                }
            }
        }
        complete.backgroundColor = AppTheme.successActionColor
        let delete = UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in
            Task { @MainActor [weak self] in
                guard let self else { done(false); return }
                do {
                    try await repository.delete(
                        id: reminder.id,
                        expectedUpdatedAt: reminder.updatedAt
                    )
                    await notificationService.cancel(
                        identifier: reminder.notificationIdentifier
                            ?? "garage.reminder.\(reminder.id.uuidString)"
                    )
                    done(true)
                    reload()
                } catch {
                    done(false)
                    presentError(error)
                }
            }
        }
        let actions = reminder.status == .completed || reminder.status == .cancelled
            ? [delete]
            : [delete, complete]
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func updateEmptyState() {
        let isCompletedFilter = selectedFilter == .completed
        let state = EmptyStateView(
            symbol: isCompletedFilter ? "checkmark.circle.fill" : "bell.badge.fill",
            title: isCompletedFilter ? "Tamamlanan hatırlatma yok" : "Aktif hatırlatma yok",
            message: isCompletedFilter
                ? "Tamamladığınız hatırlatmalar burada listelenecek."
                : "Bakım, sigorta veya kilometre hedefleri için hatırlatma oluşturun.",
            actionTitle: isCompletedFilter ? nil : "Hatırlatma Oluştur"
        ) { [weak self] in self?.onAdd?() }
        tableView.showEmptyState(state, when: visibleReminders.isEmpty)
    }

    private var visibleReminders: [Reminder] {
        let filtered = reminders.filter { reminder in
            switch selectedFilter {
            case .active: reminder.status != .completed && reminder.status != .cancelled
            case .completed: reminder.status == .completed || reminder.status == .cancelled
            }
        }
        return filtered.sorted(by: reminderSort)
    }

    private func reminderSort(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        if selectedFilter == .completed {
            return (lhs.completedAt ?? lhs.updatedAt) > (rhs.completedAt ?? rhs.updatedAt)
        }
        let lhsPriority = statusPriority(lhs.status)
        let rhsPriority = statusPriority(rhs.status)
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        if lhs.dueDate != rhs.dueDate { return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture) }
        return (lhs.dueMileage ?? .max) < (rhs.dueMileage ?? .max)
    }

    private func statusPriority(_ status: ReminderStatus) -> Int {
        switch status {
        case .overdue: 0
        case .approaching: 1
        case .active: 2
        case .completed, .cancelled: 3
        }
    }

    private func configureFilterHeader() {
        guard let header = Bundle.main.loadNibNamed("ReminderFilterHeaderView", owner: nil)?.first as? ReminderFilterHeaderView else {
            assertionFailure("ReminderFilterHeaderView.xib could not be loaded")
            return
        }
        header.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 64)
        header.configure(selectedIndex: selectedFilter.rawValue) { [weak self] index in
            guard let self, let filter = Filter(rawValue: index), filter != selectedFilter else { return }
            selectedFilter = filter
            tableView.reloadData()
            updateEmptyState()
        }
        filterHeaderView = header
        tableView.tableHeaderView = header
    }

    @objc private func add() { onAdd?() }

    @objc func reload() {
        loadGeneration += 1
        let generation = loadGeneration
        Task {
            guard let vehicle = session.selectedVehicle else {
                reminders = []
                linkedRecordTypes = [:]
                tableView.reloadData()
                updateEmptyState()
                return
            }
            do {
                let fetchedReminders = try await EvaluateReminderStatusesUseCase(repository: repository).execute(vehicle: vehicle)
                var fetchedTypes: [UUID: RecordType] = [:]
                if let recordRepository {
                    for reminder in fetchedReminders {
                        guard let recordID = reminder.recordID,
                              let record = try? await recordRepository.record(id: recordID)
                        else { continue }
                        fetchedTypes[reminder.id] = record.recordType
                    }
                }
                guard generation == loadGeneration, session.selectedVehicle?.id == vehicle.id else { return }
                reminders = fetchedReminders
                linkedRecordTypes = fetchedTypes
                tableView.reloadData()
                updateEmptyState()
            } catch {
                guard generation == loadGeneration else { return }
                presentError(error)
            }
        }
    }
}

final class ReminderEditorViewController: UITableViewController {
    private enum Section: Int, CaseIterable { case general, date, mileage }

    var onSaved: (() -> Void)?
    private let vehicle: Vehicle
    private let repository: ReminderRepository
    private let notifications: NotificationSchedulingService
    private let existingReminder: Reminder?
    private var reminderTitle = ""
    private var useDate = true
    private var dueDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    private var useMileage = false
    private var dueMileage: Int64?

    init(
        vehicle: Vehicle,
        repository: ReminderRepository,
        notifications: NotificationSchedulingService,
        existing: Reminder? = nil
    ) {
        self.vehicle = vehicle
        self.repository = repository
        self.notifications = notifications
        existingReminder = existing
        if let existing {
            reminderTitle = existing.title
            useDate = existing.dueDate != nil
            dueDate = existing.dueDate ?? dueDate
            useMileage = existing.dueMileage != nil
            dueMileage = existing.dueMileage
        }
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingReminder == nil ? "Hatırlatma Ekle" : "Hatırlatmayı Düzenle"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Vazgeç", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kaydet", style: .done, target: self, action: #selector(save))
        ["TextInputCell", "DatePickerCell", "ToggleCell", "DecimalInputCell"].forEach {
            tableView.register(UINib(nibName: $0, bundle: .main), forCellReuseIdentifier: $0)
        }
        AppTheme.styleForm(tableView)
        updateSaveButtonState()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .general: 1
        case .date: useDate ? 2 : 1
        case .mileage: useMileage ? 2 : 1
        case nil: 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) { case .general: "Genel"; case .date: "Tarih Hedefi"; case .mileage: "Kilometre Hedefi"; case nil: nil }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .date: "Tarih hedefi açıksa cihazınızda yerel bildirim planlanır."
        case .mileage: "Kilometre hedefi, aracın kilometresi güncellendiğinde değerlendirilir."
        case .general, nil: nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        switch (section, indexPath.row) {
        case (.general, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextInputCell", for: indexPath) as! TextInputCell
            cell.configure(title: "Başlık", value: reminderTitle, placeholder: "Örn. Periyodik bakım") { [weak self] value in
                self?.reminderTitle = value
                self?.updateSaveButtonState()
            }
            return cell
        case (.date, 0):
            let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
            cell.configure(title: "Tarih hedefi", isOn: useDate) { [weak self] value in
                self?.useDate = value
                self?.tableView.reloadSections(IndexSet(integer: Section.date.rawValue), with: .automatic)
                self?.updateSaveButtonState()
            }
            return cell
        case (.date, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "DatePickerCell", for: indexPath) as! DatePickerCell
            cell.configure(title: "Hedef tarih", date: dueDate) { [weak self] in self?.dueDate = $0 }
            return cell
        case (.mileage, 0):
            let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell
            cell.configure(title: "Kilometre hedefi", isOn: useMileage) { [weak self] value in
                self?.useMileage = value
                if !value { self?.dueMileage = nil }
                self?.tableView.reloadSections(IndexSet(integer: Section.mileage.rawValue), with: .automatic)
                self?.updateSaveButtonState()
            }
            return cell
        case (.mileage, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "DecimalInputCell", for: indexPath) as! DecimalInputCell
            cell.configure(title: "Hedef kilometre", value: dueMileage.map(String.init) ?? "", placeholder: "Örn. 60000", keyboardType: .numberPad, suffix: "km") { [weak self] value in
                self?.dueMileage = Int64(value)
                self?.updateSaveButtonState()
            }
            return cell
        }
    }

    private func updateSaveButtonState() {
        let hasTitle = !reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidTarget = useDate || (useMileage && dueMileage != nil)
        navigationItem.rightBarButtonItem?.isEnabled = hasTitle && hasValidTarget
    }

    @objc private func save() {
        navigationItem.rightBarButtonItem?.isEnabled = false
        Task {
            do {
                var reminder = existingReminder ?? Reminder(vehicleID: vehicle.id, title: "")
                reminder.title = reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                reminder.dueDate = useDate ? dueDate : nil
                reminder.dueMileage = useMileage ? dueMileage : nil
                reminder.updatedAt = .now
                try await CreateReminderUseCase(
                    repository: repository,
                    notificationService: notifications
                ).execute(
                    reminder,
                    expectedUpdatedAt: existingReminder?.updatedAt
                )
                onSaved?()
            } catch {
                updateSaveButtonState()
                presentError(error)
            }
        }
    }

    @objc private func cancel() { dismiss(animated: true) }
}
