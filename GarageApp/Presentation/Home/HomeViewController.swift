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
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad(); navigationItem.title = nil; navigationItem.largeTitleDisplayMode = .never; view.backgroundColor = AppTheme.backgroundColor
        titleLabel.isHidden = true; messageLabel.isHidden = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settings))
        configureLayout(); bind()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil)
        Task { await viewModel.load() }
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    private func configureLayout() {
        view.addSubview(scrollView); scrollView.pinToEdges(of: view)
        scrollView.contentInsetAdjustmentBehavior = .always
        contentStack.axis = .vertical; contentStack.spacing = AppTheme.Spacing.section
        scrollView.addSubview(contentStack); contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AppTheme.Metrics.horizontalMargin),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AppTheme.Metrics.horizontalMargin),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppTheme.Spacing.small),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.large),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(AppTheme.Metrics.horizontalMargin * 2))
        ])
        let refresh = UIRefreshControl(); refresh.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged); scrollView.refreshControl = refresh
    }

    private func bind() { viewModel.onChange = { [weak self] state in self?.render(state) } }

    private func render(_ state: HomeViewModel.State) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let pageHeader = PageHeaderView(
            title: "Ana Sayfa",
            message: "Aracınızın güncel durumunu ve yaklaşan işlemleri tek bakışta takip edin.",
            horizontalInset: 0
        )
        contentStack.addArrangedSubview(pageHeader)
        contentStack.setCustomSpacing(AppTheme.Spacing.small, after: pageHeader)
        if state.isLoading, state.vehicle == nil { return }
        guard let vehicle = state.vehicle else {
            contentStack.addArrangedSubview(EmptyStateView(symbol: "car.fill", title: "Henüz araç yok", message: "İlk aracınızı ekleyerek bakım ve masraf geçmişinizi oluşturmaya başlayın.", actionTitle: "Araç Ekle") { [weak self] in self?.onChooseVehicle?() }); return
        }
        contentStack.addArrangedSubview(vehicleCard(vehicle))
        contentStack.addArrangedSubview(quickActions())
        contentStack.addArrangedSubview(costCard(month: state.monthlyTotal, year: state.yearlyTotal))
        contentStack.addArrangedSubview(reminderCard(state.reminders))
        contentStack.addArrangedSubview(recentCard(state.recentRecords))
        if let error = state.errorMessage { contentStack.addArrangedSubview(infoLabel(error, color: AppTheme.dangerColor)) }
    }

    private func vehicleCard(_ vehicle: Vehicle) -> UIView {
        let card = VehicleSummaryCardView.instantiate()
        card.configure(
            vehicle: vehicle,
            onChooseVehicle: { [weak self] in self?.onChooseVehicle?() },
            onUpdateMileage: { [weak self] in self?.onUpdateMileage?() }
        )
        return card
    }

    private func captionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        let baseFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: baseFont)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = AppTheme.secondaryTextColor
        label.numberOfLines = 0
        return label
    }

    private func quickActions() -> UIView {
        let card = cardView()
        let title = sectionHeading(
            title: "Hızlı İşlemler",
            message: "Sık kullanılan kayıt türlerine doğrudan ulaşın."
        )
        let types: [(RecordType, String)] = [(.maintenance, "Bakım"), (.fuel, "Yakıt"), (.expense, "Masraf")]
        let buttons = types.map { type, title -> UIButton in
            var config = AppTheme.tonalButtonConfiguration(title: title, symbol: type.symbolName)
            config.imagePlacement = .leading
            config.imagePadding = 6
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)
            let button = UIButton(configuration: config)
            button.tag = RecordType.allCases.firstIndex(of: type) ?? 0
            button.addTarget(self, action: #selector(quickAction(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
            return button
        }
        let row = UIStackView(arrangedSubviews: buttons); row.distribution = .fillEqually; row.spacing = AppTheme.Spacing.small
        install(UIStackView.vertical([title, row], spacing: AppTheme.Spacing.standard), in: card); return card
    }

    private func costCard(month: Decimal, year: Decimal) -> UIView {
        let card = cardView()
        let title = sectionHeading(title: "Maliyet Özeti", message: "Dönemsel harcama toplamları")
        let formatter = AppFormatters.currency
        let monthView = metricView(title: "Bu ay", value: formatter.string(from: month as NSDecimalNumber) ?? "—")
        let yearView = metricView(title: "Bu yıl", value: formatter.string(from: year as NSDecimalNumber) ?? "—")
        let metrics = AccessibilityAxisStackView(arrangedSubviews: [monthView, yearView]); metrics.spacing = AppTheme.Spacing.medium; metrics.distribution = .fillEqually
        install(UIStackView.vertical([title, metrics], spacing: AppTheme.Spacing.medium), in: card); return card
    }

    private func metricView(title: String, value: String) -> UIView {
        let titleLabel = captionLabel(title)
        let valueLabel = label(value, style: .title3, weight: .semibold)
        let stack = UIStackView.vertical([titleLabel, valueLabel], spacing: AppTheme.Spacing.xSmall)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        AppTheme.styleBorderedSurface(stack, backgroundColor: AppTheme.inputColor)
        stack.isAccessibilityElement = true; stack.accessibilityLabel = "\(title), \(value)"
        return stack
    }

    private func reminderCard(_ reminders: [Reminder]) -> UIView {
        let card = cardView(); let header = UIButton(type: .system); header.contentHorizontalAlignment = .leading
        var headerConfig = UIButton.Configuration.plain(); headerConfig.title = "Yaklaşan İşlemler"; headerConfig.image = UIImage(systemName: "chevron.right"); headerConfig.imagePlacement = .trailing; headerConfig.imagePadding = AppTheme.Spacing.small; headerConfig.contentInsets = .zero
        header.configuration = headerConfig; header.titleLabel?.font = AppTheme.font(.headline, weight: .semibold); header.addTarget(self, action: #selector(remindersTapped), for: .touchUpInside)
        var views: [UIView] = [header]
        if reminders.isEmpty {
            views.append(infoLabel("Yaklaşan hatırlatma yok.", color: AppTheme.secondaryTextColor))
        } else {
            for (index, reminder) in reminders.prefix(3).enumerated() {
                if index > 0 { views.append(HairlineView()) }
                views.append(reminderRow(reminder))
            }
        }
        install(UIStackView.vertical(views, spacing: AppTheme.Spacing.medium), in: card); return card
    }

    private func recentCard(_ records: [VehicleRecord]) -> UIView {
        let card = cardView()
        var views: [UIView] = [sectionHeading(title: "Son Kayıtlar", message: "En son eklenen araç işlemleri")]
        if records.isEmpty {
            views.append(infoLabel("Henüz kayıt yok.", color: AppTheme.secondaryTextColor))
        } else {
            for (index, record) in records.enumerated() {
                if index > 0 { views.append(HairlineView()) }
                views.append(recordButton(record))
            }
        }
        install(UIStackView.vertical(views, spacing: AppTheme.Spacing.medium), in: card); return card
    }

    private func sectionHeading(title: String, message: String? = nil) -> UIView {
        let titleLabel = label(title, style: .headline, weight: .semibold)
        guard let message else { return titleLabel }
        let messageLabel = infoLabel(message, color: AppTheme.secondaryTextColor)
        messageLabel.font = AppTheme.font(.footnote)
        return UIStackView.vertical([titleLabel, messageLabel], spacing: AppTheme.Spacing.xSmall)
    }

    private func reminderRow(_ reminder: Reminder) -> UIView {
        let tintColor = reminder.status == .overdue ? AppTheme.dangerColor : AppTheme.warningColor
        let icon = compactIcon(symbol: reminder.status == .overdue ? "exclamationmark.circle.fill" : "bell.fill", tintColor: tintColor)
        let title = label(reminder.title, style: .subheadline, weight: .semibold)
        var details = ["Durum · \(reminder.status.displayName)"]
        if let date = reminder.dueDate { details.append("Tarih · \(AppFormatters.date.string(from: date))") }
        if let mileage = reminder.dueMileage {
            let value = AppFormatters.mileage.string(from: NSNumber(value: mileage)) ?? String(mileage)
            details.append("Kilometre · \(value) km")
        }
        let detail = infoLabel(details.joined(separator: "\n"), color: AppTheme.secondaryTextColor)
        detail.font = AppTheme.font(.footnote)
        let text = UIStackView.vertical([title, detail], spacing: AppTheme.Spacing.xSmall)
        let row = UIStackView(arrangedSubviews: [icon, text])
        row.axis = .horizontal; row.alignment = .center; row.spacing = AppTheme.Spacing.medium
        return row
    }

    private func recordButton(_ record: VehicleRecord) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = record.title
        configuration.subtitle = "\(record.recordType.displayName)\n\(AppFormatters.date.string(from: record.eventDate))"
        configuration.image = UIImage(systemName: record.recordType.symbolName)
        configuration.imagePadding = AppTheme.Spacing.medium
        configuration.baseForegroundColor = AppTheme.primaryTextColor
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        configuration.titleAlignment = .leading
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.subtitleLineBreakMode = .byWordWrapping
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.font(.subheadline, weight: .semibold)
            return attributes
        }
        configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.font(.footnote)
            attributes.foregroundColor = AppTheme.secondaryTextColor
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.tintColor = record.recordType.tintColor
        button.accessibilityLabel = "\(record.title), \(record.recordType.displayName), \(AppFormatters.date.string(from: record.eventDate))"
        button.accessibilityHint = "Kayıt detayını açar"
        button.addAction(UIAction { [weak self] _ in self?.onRecord?(record) }, for: .touchUpInside)
        return button
    }

    private func compactIcon(symbol: String, tintColor: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = tintColor.withAlphaComponent(0.11)
        container.layer.cornerRadius = AppTheme.Radius.compact
        container.layer.cornerCurve = .continuous
        let imageView = UIImageView(image: UIImage(systemName: symbol))
        imageView.tintColor = tintColor
        imageView.contentMode = .scaleAspectFit
        container.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 36),
            container.heightAnchor.constraint(equalToConstant: 36),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])
        return container
    }

    private func cardView() -> UIView { let view = UIView(); AppTheme.styleCard(view); return view }
    private func install(_ stack: UIStackView, in card: UIView) { card.addSubview(stack); stack.pinToEdges(of: card, insets: NSDirectionalEdgeInsets(top: AppTheme.Metrics.cardPadding, leading: AppTheme.Metrics.cardPadding, bottom: AppTheme.Metrics.cardPadding, trailing: AppTheme.Metrics.cardPadding)) }
    private func label(_ text: String, style: UIFont.TextStyle, weight: UIFont.Weight) -> UILabel { let label = UILabel(); label.text = text; label.font = AppTheme.font(style, weight: weight); label.adjustsFontForContentSizeCategory = true; label.textColor = AppTheme.primaryTextColor; label.numberOfLines = 0; return label }
    private func infoLabel(_ text: String, color: UIColor?) -> UILabel { let label = UILabel(); label.text = text; label.font = AppTheme.font(.body); label.adjustsFontForContentSizeCategory = true; label.textColor = color ?? AppTheme.primaryTextColor; label.numberOfLines = 0; return label }

    @objc private func settings() { onSettings?() }
    @objc private func remindersTapped() { onReminders?() }
    @objc private func quickAction(_ sender: UIButton) { guard RecordType.allCases.indices.contains(sender.tag) else { return }; onAddRecord?(RecordType.allCases[sender.tag]) }
    @objc private func reload() { Task { await viewModel.load() } }
    @objc private func refresh(_ control: UIRefreshControl) { Task { await viewModel.load(); control.endRefreshing() } }
}

private extension UIStackView {
    static func vertical(_ views: [UIView], spacing: CGFloat) -> UIStackView { let stack = UIStackView(arrangedSubviews: views); stack.axis = .vertical; stack.spacing = spacing; return stack }
}

private final class AccessibilityAxisStackView: UIStackView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        alignment = .fill
        updateLayoutForContentSizeCategory()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (stack: AccessibilityAxisStackView, _) in
            stack.updateLayoutForContentSizeCategory()
        }
    }

    @available(*, unavailable) required init(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateLayoutForContentSizeCategory()
    }

    private func updateLayoutForContentSizeCategory() {
        let usesVerticalLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        axis = usesVerticalLayout ? .vertical : .horizontal
        distribution = usesVerticalLayout ? .fill : .fillEqually
    }
}
