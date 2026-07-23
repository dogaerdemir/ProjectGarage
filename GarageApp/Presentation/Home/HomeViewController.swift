//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class HomeViewController: UIViewController {
    var viewModel: HomeViewModel!
    var onSettings: (() -> Void)?
    var onChooseVehicle: (() -> Void)?
    var onAddRecord: ((RecordType) -> Void)?
    var onUpdateMileage: (() -> Void)?
    var onReminders: (() -> Void)?
    var onRecord: ((VehicleRecord) -> Void)?
    var onShowTimeline: (() -> Void)?
    var onShowInsights: (() -> Void)?

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!

    private enum CostPeriod: Int {
        case month
        case year
    }

    private let headerView = HomeHeaderView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var latestState = HomeViewModel.State()
    private var costPeriod: CostPeriod = .month
    private weak var costValueLabel: UILabel?
    private weak var costSummaryAccessibilityView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = nil
        view.backgroundColor = AppTheme.backgroundColor
        titleLabel.isHidden = true
        messageLabel.isHidden = true
        configureLayout()
        bind()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil)
        Task { await viewModel.load() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func configureLayout() {
        headerView.onTap = { [weak self] in self?.onChooseVehicle?() }
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        contentStack.axis = .vertical
        contentStack.spacing = AppTheme.Spacing.medium
        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Metrics.horizontalMargin),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Metrics.horizontalMargin),

            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AppTheme.Metrics.horizontalMargin),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AppTheme.Metrics.horizontalMargin),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.large),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(AppTheme.Metrics.horizontalMargin * 2))
        ])

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        scrollView.refreshControl = refresh
    }

    private func bind() {
        viewModel.onChange = { [weak self] state in self?.render(state) }
    }

    private func render(_ state: HomeViewModel.State) {
        latestState = state
        headerView.configure(vehicle: state.vehicle)
        costValueLabel = nil
        costSummaryAccessibilityView = nil
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if state.isLoading, state.vehicle == nil {
            let loading = LoadingView()
            loading.heightAnchor.constraint(equalToConstant: 160).isActive = true
            contentStack.addArrangedSubview(loading)
            return
        }

        guard let vehicle = state.vehicle else {
            let emptyState = EmptyStateView(
                symbol: "car.fill",
                title: "Henüz araç yok",
                message: "İlk aracınızı ekleyerek bakım ve masraf geçmişinizi oluşturmaya başlayın.",
                actionTitle: "Araç Ekle"
            ) { [weak self] in
                self?.onChooseVehicle?()
            }
            contentStack.addArrangedSubview(emptyState)
            return
        }

        contentStack.addArrangedSubview(vehicleCard(vehicle, imageData: state.vehicleImageData))
        contentStack.addArrangedSubview(quickActions())
        contentStack.addArrangedSubview(costCard(month: state.monthlyTotal, year: state.yearlyTotal))
        let featured = featuredReminder(in: state.reminders)
        contentStack.addArrangedSubview(nextReminderCard(featured, vehicle: vehicle))
        let remainingReminders = state.reminders.filter { $0.reminder.id != featured?.reminder.id }
        contentStack.addArrangedSubview(upcomingRemindersSection(remainingReminders, vehicle: vehicle))
        contentStack.addArrangedSubview(recentRecordsSection(state.recentRecords))

        if let error = state.errorMessage {
            contentStack.addArrangedSubview(infoLabel(error, color: AppTheme.dangerColor))
        }
    }

    private func vehicleCard(_ vehicle: Vehicle, imageData: Data?) -> UIView {
        let card = VehicleSummaryCardView.instantiate()
        card.configure(
            vehicle: vehicle,
            imageData: imageData,
            onUpdateMileage: { [weak self] in self?.onUpdateMileage?() }
        )
        return card
    }

    private func quickActions() -> UIView {
        let title = label("Hızlı İşlemler", style: .headline, weight: .semibold)
        let types: [(RecordType, String)] = [(.maintenance, "Bakım"), (.fuel, "Yakıt"), (.expense, "Masraf")]
        let buttons = types.map { type, title -> UIButton in
            var configuration = AppTheme.secondaryButtonConfiguration(title: title, symbol: type.symbolName)
            configuration.imagePlacement = .top
            configuration.imagePadding = AppTheme.Spacing.small
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 6, bottom: 10, trailing: 6)
            let button = UIButton(configuration: configuration)
            button.tag = RecordType.allCases.firstIndex(of: type) ?? 0
            button.addTarget(self, action: #selector(quickAction(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 82).isActive = true
            button.accessibilityHint = "Yeni \(title.lowercased(with: Locale(identifier: "tr_TR"))) kaydı ekler"
            return button
        }
        let row = UIStackView(arrangedSubviews: buttons)
        row.distribution = .fillEqually
        row.spacing = AppTheme.Spacing.small
        return UIStackView.vertical([title, row], spacing: AppTheme.Spacing.small)
    }

    private func costCard(month: Decimal, year: Decimal) -> UIView {
        let card = cardView()
        let title = label("Maliyet Özeti", style: .subheadline, weight: .semibold)
        let periodControl = UISegmentedControl(items: ["Bu Ay", "Bu Yıl"])
        periodControl.selectedSegmentIndex = costPeriod.rawValue
        periodControl.addTarget(self, action: #selector(costPeriodChanged(_:)), for: .valueChanged)
        AppTheme.styleSegmentedControl(periodControl)
        periodControl.widthAnchor.constraint(equalToConstant: 132).isActive = true
        periodControl.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let header = UIStackView(arrangedSubviews: [title, periodControl])
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .equalSpacing

        let iconSurface = iconSurface(symbol: "wallet.bifold.fill", tint: AppTheme.accentColor, size: 44)
        let metricTitle = label("Toplam Maliyet", style: .caption1, weight: .regular)
        metricTitle.textColor = AppTheme.secondaryTextColor
        let value = label(formattedCurrency(costPeriod == .month ? month : year), style: .title1, weight: .bold)
        value.textColor = AppTheme.accentColor
        costValueLabel = value
        let metricLabels = UIStackView.vertical([metricTitle, value], spacing: 1)

        let body = UIView()
        body.isAccessibilityElement = true
        body.accessibilityLabel = "Toplam maliyet, \(value.text ?? "")"
        costSummaryAccessibilityView = body
        let bodyStack = UIStackView(arrangedSubviews: [iconSurface, metricLabels, UIView()])
        bodyStack.axis = .horizontal
        bodyStack.alignment = .center
        bodyStack.spacing = AppTheme.Spacing.medium
        body.addSubview(bodyStack)
        bodyStack.pinToEdges(of: body)

        install(UIStackView.vertical([header, body], spacing: AppTheme.Spacing.medium), in: card)
        return card
    }

    private func nextReminderCard(_ item: HomeViewModel.ReminderItem?, vehicle: Vehicle) -> UIView {
        let card = cardView()
        let title = label("Yaklaşan", style: .subheadline, weight: .semibold)
        let row: UIView
        if let item {
            row = reminderRow(item, vehicle: vehicle, compact: false)
        } else {
            row = infoLabel("Yaklaşan işlem bulunmuyor.", color: AppTheme.secondaryTextColor)
        }
        install(UIStackView.vertical([title, row], spacing: AppTheme.Spacing.medium), in: card)
        return card
    }

    private func featuredReminder(in reminders: [HomeViewModel.ReminderItem]) -> HomeViewModel.ReminderItem? {
        reminders.first { item in
            item.reminder.dueMileage != nil && item.reminder.status != .overdue
        } ?? reminders.first
    }

    private func upcomingRemindersSection(_ reminders: [HomeViewModel.ReminderItem], vehicle: Vehicle) -> UIView {
        let title = label("Yaklaşan İşlemler", style: .headline, weight: .semibold)
        let card = cardView()
        var rows: [UIView] = []
        if reminders.isEmpty {
            rows.append(infoLabel("Aktif hatırlatma bulunmuyor.", color: AppTheme.secondaryTextColor))
        } else {
            for (index, item) in reminders.prefix(2).enumerated() {
                if index > 0 { rows.append(HairlineView()) }
                rows.append(reminderRow(item, vehicle: vehicle, compact: true))
            }
        }
        install(UIStackView.vertical(rows, spacing: 0), in: card)
        return UIStackView.vertical([title, card], spacing: AppTheme.Spacing.small)
    }

    private func reminderRow(_ item: HomeViewModel.ReminderItem, vehicle: Vehicle, compact: Bool) -> UIView {
        let reminder = item.reminder
        let row = ActionRowView { [weak self] in self?.onReminders?() }
        row.accessibilityLabel = "\(reminder.title), \(remainingDescription(reminder, vehicle: vehicle, compact: compact))"
        row.accessibilityHint = "Hatırlatmaları açar"

        let icon = iconSurface(
            symbol: reminderSymbol(item),
            tint: reminder.status == .overdue ? AppTheme.dangerColor : AppTheme.accentColor,
            size: compact ? 40 : 44
        )
        let title = label(reminder.title, style: compact ? .subheadline : .body, weight: .semibold)
        let status = label(remainingDescription(reminder, vehicle: vehicle, compact: compact), style: .subheadline, weight: .medium)
        status.textColor = reminder.status == .overdue
            ? AppTheme.dangerColor
            : (reminder.dueDate != nil ? AppTheme.warningColor : AppTheme.accentColor)
        let labels = UIStackView.vertical([title, status], spacing: 2)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppTheme.secondaryTextColor
        chevron.contentMode = .scaleAspectFit
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        let stack = UIStackView(arrangedSubviews: [icon, labels, UIView(), chevron])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = AppTheme.Spacing.medium
        row.addSubview(stack)
        stack.pinToEdges(
            of: row,
            insets: NSDirectionalEdgeInsets(top: compact ? 8 : 4, leading: 0, bottom: compact ? 8 : 4, trailing: 0)
        )
        return row
    }

    private func recentRecordsSection(_ records: [VehicleRecord]) -> UIView {
        let title = label("Son Kayıtlar", style: .headline, weight: .semibold)
        let allButton = UIButton(type: .system)
        var allConfiguration = UIButton.Configuration.plain()
        allConfiguration.title = "Tümünü Gör"
        allConfiguration.baseForegroundColor = AppTheme.accentColor
        allConfiguration.contentInsets = .zero
        allConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.font(.subheadline, weight: .medium)
            return attributes
        }
        allButton.configuration = allConfiguration
        allButton.addTarget(self, action: #selector(showTimeline), for: .touchUpInside)
        let header = UIStackView(arrangedSubviews: [title, UIView(), allButton])
        header.axis = .horizontal
        header.alignment = .center

        let card = cardView()
        var rows: [UIView] = []
        if records.isEmpty {
            rows.append(infoLabel("Henüz kayıt yok.", color: AppTheme.secondaryTextColor))
        } else {
            for (index, record) in records.prefix(2).enumerated() {
                if index > 0 { rows.append(HairlineView()) }
                rows.append(recentRecordRow(record))
            }
        }
        install(UIStackView.vertical(rows, spacing: 0), in: card)
        return UIStackView.vertical([header, card], spacing: AppTheme.Spacing.small)
    }

    private func recentRecordRow(_ record: VehicleRecord) -> UIView {
        let row = UIView()
        row.isAccessibilityElement = true
        row.accessibilityLabel = [
            record.title,
            AppFormatters.date.string(from: record.eventDate),
            record.totalAmount.map { formattedCurrency($0) }
        ]
            .compactMap { $0 }
            .joined(separator: ", ")

        let icon = iconSurface(symbol: record.recordType.symbolName, tint: record.recordType.tintColor, size: 42)
        let title = label(record.title, style: .subheadline, weight: .semibold)
        let date = label(AppFormatters.date.string(from: record.eventDate), style: .caption1, weight: .regular)
        date.textColor = AppTheme.secondaryTextColor
        let labels = UIStackView.vertical([title, date], spacing: 2)
        let amount = label(record.totalAmount.map { formattedCurrency($0) } ?? "", style: .subheadline, weight: .semibold)
        amount.textAlignment = .right
        amount.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [icon, labels, UIView(), amount])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = AppTheme.Spacing.small
        row.addSubview(stack)
        stack.pinToEdges(of: row, insets: NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        return row
    }

    private func iconSurface(symbol: String, tint: UIColor, size: CGFloat) -> UIView {
        let surface = UIView()
        surface.backgroundColor = tint.withAlphaComponent(0.10)
        surface.layer.cornerRadius = size / 2
        surface.layer.cornerCurve = .continuous
        surface.widthAnchor.constraint(equalToConstant: size).isActive = true
        surface.heightAnchor.constraint(equalToConstant: size).isActive = true
        let image = UIImageView(image: UIImage(systemName: symbol))
        image.tintColor = tint
        image.contentMode = .scaleAspectFit
        surface.addSubview(image)
        image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            image.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: size * 0.48),
            image.heightAnchor.constraint(equalToConstant: size * 0.48)
        ])
        return surface
    }

    private func reminderSymbol(_ item: HomeViewModel.ReminderItem) -> String {
        if let recordType = item.recordType {
            switch recordType {
            case .maintenance: return "calendar.badge.clock"
            case .insurance: return "shield.checkered"
            case .inspection: return "checkmark.seal"
            default: return recordType.symbolName
            }
        }
        let title = item.reminder.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if title.contains("sigorta") || title.contains("kasko") { return "shield.checkered" }
        if title.contains("bakim") { return "calendar.badge.clock" }
        if title.contains("muayene") { return "checkmark.seal" }
        return "bell"
    }

    private func remainingDescription(_ reminder: Reminder, vehicle: Vehicle, compact: Bool) -> String {
        if let dueMileage = reminder.dueMileage {
            let difference = dueMileage - vehicle.currentMileage
            let value = AppFormatters.mileage.string(from: NSNumber(value: abs(difference))) ?? String(abs(difference))
            if difference < 0 { return "\(value) km geçti" }
            if difference == 0 { return "Kilometresi geldi" }
            return compact ? "\(value) km" : "\(value) km kaldı"
        }
        if let dueDate = reminder.dueDate {
            let calendar = Calendar.autoupdatingCurrent
            let start = calendar.startOfDay(for: .now)
            let end = calendar.startOfDay(for: dueDate)
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            if days < 0 { return "\(abs(days)) gün geçti" }
            if days == 0 { return "Bugün" }
            return compact ? "\(days) gün" : "\(days) gün kaldı"
        }
        return reminder.status.displayName
    }

    private func formattedCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let value = formatter.string(from: amount as NSDecimalNumber) ?? "—"
        return "\(value) ₺"
    }

    private func cardView() -> UIView {
        let view = UIView()
        AppTheme.styleCard(view)
        return view
    }

    private func install(_ stack: UIStackView, in card: UIView) {
        card.addSubview(stack)
        stack.pinToEdges(
            of: card,
            insets: NSDirectionalEdgeInsets(
                top: AppTheme.Metrics.cardPadding,
                leading: AppTheme.Metrics.cardPadding,
                bottom: AppTheme.Metrics.cardPadding,
                trailing: AppTheme.Metrics.cardPadding
            )
        )
    }

    private func label(_ text: String, style: UIFont.TextStyle, weight: UIFont.Weight) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.font(style, weight: weight)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = AppTheme.primaryTextColor
        label.numberOfLines = 0
        return label
    }

    private func infoLabel(_ text: String, color: UIColor?) -> UILabel {
        let label = label(text, style: .subheadline, weight: .regular)
        label.textColor = color ?? AppTheme.primaryTextColor
        return label
    }

    @objc private func costPeriodChanged(_ sender: UISegmentedControl) {
        costPeriod = CostPeriod(rawValue: sender.selectedSegmentIndex) ?? .month
        let amount = costPeriod == .month ? latestState.monthlyTotal : latestState.yearlyTotal
        costValueLabel?.text = formattedCurrency(amount)
        costSummaryAccessibilityView?.accessibilityLabel = "Toplam maliyet, \(formattedCurrency(amount))"
    }

    @objc private func showTimeline() {
        if let onShowTimeline {
            onShowTimeline()
        } else {
            tabBarController?.selectedIndex = 1
        }
    }

    @objc private func quickAction(_ sender: UIButton) {
        guard RecordType.allCases.indices.contains(sender.tag) else { return }
        onAddRecord?(RecordType.allCases[sender.tag])
    }

    @objc private func reload() { Task { await viewModel.load() } }

    @objc private func refresh(_ control: UIRefreshControl) {
        Task {
            await viewModel.load()
            control.endRefreshing()
        }
    }
}

private final class ActionRowView: UIControl {
    init(_ action: @escaping () -> Void) {
        super.init(frame: .zero)
        addAction(UIAction { _ in action() }, for: .touchUpInside)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) { self.alpha = self.isHighlighted ? 0.55 : 1 }
        }
    }
}

private final class HomeHeaderView: UIView {
    var onTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let selector = HomeVehicleSelectorControl()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.text = "Garajım"
        titleLabel.font = AppTheme.font(.title1, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.accessibilityTraits = .header
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        selector.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [titleLabel, UIView(), selector])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = AppTheme.Spacing.small
        addSubview(stack)
        stack.pinToEdges(of: self, insets: NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
    }

    func configure(vehicle: Vehicle?) {
        selector.configure(vehicle: vehicle)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

private final class HomeVehicleSelectorControl: UIControl {
    private let vehicleImageView = UIImageView(image: UIImage(systemName: "car.side"))
    private let valueLabel = UILabel()
    private let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.down"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppTheme.surfaceColor
        layer.cornerRadius = AppTheme.Radius.control
        layer.cornerCurve = .continuous
        layer.borderWidth = AppTheme.Metrics.borderWidth
        layer.borderColor = AppTheme.borderColor.cgColor

        vehicleImageView.tintColor = AppTheme.secondaryTextColor
        vehicleImageView.contentMode = .scaleAspectFit
        valueLabel.font = AppTheme.font(.caption1, weight: .semibold)
        valueLabel.textColor = AppTheme.primaryTextColor
        valueLabel.text = "Araç Değiştir"
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        chevronImageView.tintColor = AppTheme.accentColor
        chevronImageView.contentMode = .scaleAspectFit

        let stack = UIStackView(arrangedSubviews: [vehicleImageView, valueLabel, chevronImageView])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 7
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        stack.pinToEdges(of: self, insets: NSDirectionalEdgeInsets(top: 8, leading: 11, bottom: 8, trailing: 11))
        vehicleImageView.widthAnchor.constraint(equalToConstant: 18).isActive = true
        chevronImageView.widthAnchor.constraint(equalToConstant: 12).isActive = true
        widthAnchor.constraint(lessThanOrEqualToConstant: 184).isActive = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "Araç Değiştir"
        accessibilityHint = "Araç listesini açar"
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (control: HomeVehicleSelectorControl, _) in
            control.layer.borderColor = AppTheme.borderColor.resolvedColor(with: control.traitCollection).cgColor
        }
    }

    func configure(vehicle: Vehicle?) {
        let vehicleName = vehicle.map {
            [$0.make, $0.model]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        accessibilityValue = vehicleName?.nonEmpty
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.55 : 1 }
    }
}

private extension UIStackView {
    static func vertical(_ views: [UIView], spacing: CGFloat) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = spacing
        return stack
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
