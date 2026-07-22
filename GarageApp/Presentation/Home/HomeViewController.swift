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
        contentStack.axis = .vertical; contentStack.spacing = AppTheme.Spacing.standard
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
        let pageHeader = PageHeaderView(title: "Ana Sayfa", horizontalInset: 0)
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
        label.textColor = UIColor(named: "SecondaryText")
        label.numberOfLines = 0
        return label
    }

    private func quickActions() -> UIView {
        let card = cardView(); let title = label("Hızlı İşlemler", style: .headline, weight: .semibold)
        let types: [(RecordType, String)] = [(.maintenance, "Bakım"), (.fuel, "Yakıt"), (.expense, "Masraf")]
        let buttons = types.map { type, title -> UIButton in
            var config = AppTheme.secondaryButtonConfiguration(title: title, symbol: type.symbolName); config.imagePlacement = .top; config.imagePadding = AppTheme.Spacing.small
            let button = UIButton(configuration: config); button.tag = RecordType.allCases.firstIndex(of: type) ?? 0; button.addTarget(self, action: #selector(quickAction(_:)), for: .touchUpInside); button.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true; return button
        }
        let row = UIStackView(arrangedSubviews: buttons); row.distribution = .fillEqually; row.spacing = 8
        install(UIStackView.vertical([title, row], spacing: 12), in: card); return card
    }

    private func costCard(month: Decimal, year: Decimal) -> UIView {
        let card = cardView(); let title = label("Maliyet Özeti", style: .headline, weight: .semibold)
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
        stack.isAccessibilityElement = true; stack.accessibilityLabel = "\(title), \(value)"
        return stack
    }

    private func reminderCard(_ reminders: [Reminder]) -> UIView {
        let card = cardView(); let header = UIButton(type: .system); header.contentHorizontalAlignment = .leading
        var headerConfig = UIButton.Configuration.plain(); headerConfig.title = "Yaklaşan İşlemler"; headerConfig.image = UIImage(systemName: "chevron.right"); headerConfig.imagePlacement = .trailing; headerConfig.imagePadding = AppTheme.Spacing.small; headerConfig.contentInsets = .zero
        header.configuration = headerConfig; header.titleLabel?.font = AppTheme.font(.headline, weight: .semibold); header.addTarget(self, action: #selector(remindersTapped), for: .touchUpInside)
        var views: [UIView] = [header]
        if reminders.isEmpty { views.append(infoLabel("Yaklaşan hatırlatma yok.", color: UIColor(named: "SecondaryText"))) }
        else { views += reminders.prefix(3).map { infoLabel("• \($0.title) — \($0.status.displayName)", color: $0.status == .overdue ? AppTheme.dangerColor : nil) } }
        install(UIStackView.vertical(views, spacing: 8), in: card); return card
    }

    private func recentCard(_ records: [VehicleRecord]) -> UIView {
        let card = cardView(); var views: [UIView] = [label("Son Kayıtlar", style: .headline, weight: .semibold)]
        if records.isEmpty { views.append(infoLabel("Henüz kayıt yok.", color: UIColor(named: "SecondaryText"))) }
        else { views += records.map { record in
            var config = UIButton.Configuration.plain(); config.title = record.title; config.subtitle = "\(record.recordType.displayName) • \(AppFormatters.date.string(from: record.eventDate))"; config.image = UIImage(systemName: record.recordType.symbolName); config.imagePadding = 10
            let button = UIButton(configuration: config); button.contentHorizontalAlignment = .leading; button.accessibilityHint = "Kayıt detayını açar"; button.addAction(UIAction { [weak self] _ in self?.onRecord?(record) }, for: .touchUpInside); return button
        } }
        install(UIStackView.vertical(views, spacing: 6), in: card); return card
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
