//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class ReminderListViewController: UITableViewController {
    var onAdd: (() -> Void)?
    private let session: AppSession; private let repository: ReminderRepository
    private var reminders: [Reminder] = []
    init(session: AppSession, repository: ReminderRepository) { self.session = session; self.repository = repository; super.init(style: .insetGrouped) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() { super.viewDidLoad(); title = "Hatırlatmalar"; navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add)); tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Reminder"); reload() }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { reminders.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reminder = reminders[indexPath.row]; let cell = tableView.dequeueReusableCell(withIdentifier: "Reminder", for: indexPath); var config = cell.defaultContentConfiguration(); config.text = reminder.title
        var pieces = [reminder.status.displayName]; if let date = reminder.dueDate { pieces.append(AppFormatters.date.string(from: date)) }; if let km = reminder.dueMileage { pieces.append("\(km) km") }; config.secondaryText = pieces.joined(separator: " • "); config.image = UIImage(systemName: reminder.status == .overdue ? "exclamationmark.circle.fill" : "bell.fill"); config.imageProperties.tintColor = reminder.status == .overdue ? .systemRed : .systemOrange; cell.contentConfiguration = config; return cell
    }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let reminder = reminders[indexPath.row]
        let complete = UIContextualAction(style: .normal, title: "Tamamla") { [weak self] _, _, done in var updated = reminder; updated.status = .completed; updated.completedAt = .now; Task { try? await self?.repository.save(updated); self?.reload() }; done(true) }; complete.backgroundColor = .systemGreen
        let delete = UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in Task { try? await self?.repository.delete(id: reminder.id); self?.reload() }; done(true) }
        return UISwipeActionsConfiguration(actions: [delete, complete])
    }
    @objc private func add() { onAdd?() }
    @objc func reload() { Task { guard let id = session.selectedVehicle?.id else { reminders = []; tableView.reloadData(); return }; reminders = (try? await repository.fetchReminders(vehicleID: id)) ?? []; tableView.reloadData() } }
}

final class ReminderEditorViewController: UITableViewController {
    var onSaved: (() -> Void)?
    private let vehicle: Vehicle; private let repository: ReminderRepository; private let notifications: NotificationSchedulingService
    private var reminderTitle = "", useDate = true, dueDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now, useMileage = false, dueMileage: Int64?
    init(vehicle: Vehicle, repository: ReminderRepository, notifications: NotificationSchedulingService) { self.vehicle = vehicle; self.repository = repository; self.notifications = notifications; super.init(style: .insetGrouped) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() { super.viewDidLoad(); title = "Hatırlatma Ekle"; navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Vazgeç", style: .plain, target: self, action: #selector(cancel)); navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kaydet", style: .done, target: self, action: #selector(save)); ["TextInputCell", "DatePickerCell", "ToggleCell", "DecimalInputCell"].forEach { tableView.register(UINib(nibName: $0, bundle: .main), forCellReuseIdentifier: $0) } }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 5 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0: let cell = tableView.dequeueReusableCell(withIdentifier: "TextInputCell", for: indexPath) as! TextInputCell; cell.fieldTitleLabel.text = "Başlık"; cell.textField.addAction(UIAction { [weak self] action in self?.reminderTitle = (action.sender as? UITextField)?.text ?? "" }, for: .editingChanged); return cell
        case 1, 3: let cell = tableView.dequeueReusableCell(withIdentifier: "ToggleCell", for: indexPath) as! ToggleCell; let isDate = indexPath.row == 1; cell.fieldTitleLabel.text = isDate ? "Tarih hedefi" : "Kilometre hedefi"; cell.toggle.isOn = isDate ? useDate : useMileage; cell.toggle.addAction(UIAction { [weak self] action in if isDate { self?.useDate = (action.sender as? UISwitch)?.isOn ?? false } else { self?.useMileage = (action.sender as? UISwitch)?.isOn ?? false } }, for: .valueChanged); return cell
        case 2: let cell = tableView.dequeueReusableCell(withIdentifier: "DatePickerCell", for: indexPath) as! DatePickerCell; cell.fieldTitleLabel.text = "Hedef tarih"; cell.datePicker.date = dueDate; cell.datePicker.addAction(UIAction { [weak self] action in self?.dueDate = (action.sender as? UIDatePicker)?.date ?? .now }, for: .valueChanged); return cell
        default: let cell = tableView.dequeueReusableCell(withIdentifier: "DecimalInputCell", for: indexPath) as! DecimalInputCell; cell.fieldTitleLabel.text = "Hedef kilometre"; cell.textField.keyboardType = .numberPad; cell.textField.addAction(UIAction { [weak self] action in self?.dueMileage = Int64((action.sender as? UITextField)?.text ?? "") }, for: .editingChanged); return cell
        }
    }
    @objc private func save() { Task { do { let reminder = Reminder(vehicleID: vehicle.id, title: reminderTitle, dueDate: useDate ? dueDate : nil, dueMileage: useMileage ? dueMileage : nil); try await CreateReminderUseCase(repository: repository, notificationService: notifications).execute(reminder); onSaved?() } catch { presentError(error) } } }
    @objc private func cancel() { dismiss(animated: true) }
}
