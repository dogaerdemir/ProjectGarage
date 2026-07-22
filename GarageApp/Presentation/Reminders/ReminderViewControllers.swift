//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class ReminderListViewController: UITableViewController {
    var onAdd: (() -> Void)?
    private let session: AppSession
    private let repository: ReminderRepository
    private var reminders: [Reminder] = []

    init(session: AppSession, repository: ReminderRepository) {
        self.session = session
        self.repository = repository
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = nil
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        tableView.register(UINib(nibName: "DataListCell", bundle: .main), forCellReuseIdentifier: "DataListCell")
        AppTheme.styleList(tableView)
        tableView.sectionHeaderTopPadding = 0
        tableView.tableHeaderView = PageHeaderView(
            title: "Hatırlatmalar",
            message: "Yaklaşan tarih ve kilometre hedeflerinizi düzenli biçimde takip edin."
        )
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: ReminderListViewController, _) in
            controller.tableView.updateTableHeaderHeightIfNeeded()
        }
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.updateTableHeaderHeightIfNeeded()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { reminders.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reminder = reminders[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "DataListCell", for: indexPath) as! DataListCell
        var metadata: [String] = []
        if let date = reminder.dueDate { metadata.append("Tarih · \(AppFormatters.date.string(from: date))") }
        if let km = reminder.dueMileage {
            let value = AppFormatters.mileage.string(from: NSNumber(value: km)) ?? String(km)
            metadata.append("Kilometre · \(value) km")
        }
        let tintColor = reminder.status == .overdue ? AppTheme.dangerColor : AppTheme.warningColor
        cell.configure(
            title: reminder.title,
            subtitle: "Durum · \(reminder.status.displayName)",
            metadata: metadata,
            symbol: reminder.status == .overdue ? "exclamationmark.circle.fill" : "bell.fill",
            tintColor: tintColor,
            showsDisclosure: false
        )
        return cell
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let reminder = reminders[indexPath.row]
        let complete = UIContextualAction(style: .normal, title: "Tamamla") { [weak self] _, _, done in
            var updated = reminder
            updated.status = .completed
            updated.completedAt = .now
            Task { @MainActor [weak self] in
                guard let self else { done(false); return }
                do {
                    try await repository.save(updated)
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
                    try await repository.delete(id: reminder.id)
                    done(true)
                    reload()
                } catch {
                    done(false)
                    presentError(error)
                }
            }
        }
        return UISwipeActionsConfiguration(actions: [delete, complete])
    }

    private func updateEmptyState() {
        let state = EmptyStateView(
            symbol: "bell.badge.fill",
            title: "Hatırlatma yok",
            message: "Bakım, sigorta veya kilometre hedefleri için hatırlatma oluşturun.",
            actionTitle: "Hatırlatma Oluştur"
        ) { [weak self] in self?.onAdd?() }
        tableView.showEmptyState(state, when: reminders.isEmpty)
    }

    @objc private func add() { onAdd?() }

    @objc func reload() {
        Task {
            guard let id = session.selectedVehicle?.id else {
                reminders = []
                tableView.reloadData()
                updateEmptyState()
                return
            }
            do {
                reminders = try await repository.fetchReminders(vehicleID: id)
                tableView.reloadData()
                updateEmptyState()
            } catch {
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
    private var reminderTitle = ""
    private var useDate = true
    private var dueDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    private var useMileage = false
    private var dueMileage: Int64?

    init(vehicle: Vehicle, repository: ReminderRepository, notifications: NotificationSchedulingService) {
        self.vehicle = vehicle
        self.repository = repository
        self.notifications = notifications
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hatırlatma Ekle"
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
                let reminder = Reminder(vehicleID: vehicle.id, title: reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines), dueDate: useDate ? dueDate : nil, dueMileage: useMileage ? dueMileage : nil)
                try await CreateReminderUseCase(repository: repository, notificationService: notifications).execute(reminder)
                onSaved?()
            } catch {
                updateSaveButtonState()
                presentError(error)
            }
        }
    }

    @objc private func cancel() { dismiss(animated: true) }
}
