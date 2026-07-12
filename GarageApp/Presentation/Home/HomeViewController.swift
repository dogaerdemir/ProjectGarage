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
        super.viewDidLoad(); title = "Ana Sayfa"
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
        contentStack.axis = .vertical; contentStack.spacing = 16
        scrollView.addSubview(contentStack); contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        let refresh = UIRefreshControl(); refresh.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged); scrollView.refreshControl = refresh
    }

    private func bind() { viewModel.onChange = { [weak self] state in self?.render(state) } }

    private func render(_ state: HomeViewModel.State) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let vehicle = state.vehicle else {
            contentStack.addArrangedSubview(EmptyStateView(symbol: "car.fill", title: "Henüz araç yok", message: "Ayarlar bölümünden ilk aracınızı ekleyin.")); return
        }
        contentStack.addArrangedSubview(vehicleCard(vehicle))
        contentStack.addArrangedSubview(quickActions())
        contentStack.addArrangedSubview(costCard(month: state.monthlyTotal, year: state.yearlyTotal))
        contentStack.addArrangedSubview(reminderCard(state.reminders))
        contentStack.addArrangedSubview(recentCard(state.recentRecords))
        if let error = state.errorMessage { contentStack.addArrangedSubview(infoLabel(error, color: .systemRed)) }
    }

    private func vehicleCard(_ vehicle: Vehicle) -> UIView {
        let card = cardView(); let name = label(vehicle.nickname, style: .title2, weight: .bold)
        let detail = infoLabel("\(vehicle.make) \(vehicle.model)", color: UIColor(named: "SecondaryText"))
        let mileage = label("\(AppFormatters.mileage.string(from: NSNumber(value: vehicle.currentMileage)) ?? String(vehicle.currentMileage)) km", style: .title1, weight: .bold)
        let choose = UIButton(type: .system); choose.setTitle("Araç Değiştir", for: .normal); choose.addTarget(self, action: #selector(chooseVehicle), for: .touchUpInside)
        let update = UIButton(type: .system); update.setTitle("Kilometre Güncelle", for: .normal); update.addTarget(self, action: #selector(updateMileage), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [choose, update]); buttons.distribution = .fillEqually
        install(UIStackView.vertical([name, detail, mileage, buttons], spacing: 8), in: card); return card
    }

    private func quickActions() -> UIView {
        let card = cardView(); let title = label("Hızlı İşlemler", style: .headline, weight: .semibold)
        let types: [(RecordType, String)] = [(.maintenance, "Bakım"), (.fuel, "Yakıt"), (.expense, "Masraf")]
        let buttons = types.map { type, title -> UIButton in
            var config = UIButton.Configuration.tinted(); config.title = title; config.image = UIImage(systemName: type.symbolName); config.imagePlacement = .top; config.imagePadding = 6
            let button = UIButton(configuration: config); button.tag = RecordType.allCases.firstIndex(of: type) ?? 0; button.addTarget(self, action: #selector(quickAction(_:)), for: .touchUpInside); return button
        }
        let row = UIStackView(arrangedSubviews: buttons); row.distribution = .fillEqually; row.spacing = 8
        install(UIStackView.vertical([title, row], spacing: 12), in: card); return card
    }

    private func costCard(month: Decimal, year: Decimal) -> UIView {
        let card = cardView(); let title = label("Maliyet Özeti", style: .headline, weight: .semibold)
        let formatter = AppFormatters.currency
        let monthLabel = infoLabel("Bu ay: \(formatter.string(from: month as NSDecimalNumber) ?? "—")", color: nil)
        let yearLabel = infoLabel("Bu yıl: \(formatter.string(from: year as NSDecimalNumber) ?? "—")", color: nil)
        install(UIStackView.vertical([title, monthLabel, yearLabel], spacing: 8), in: card); return card
    }

    private func reminderCard(_ reminders: [Reminder]) -> UIView {
        let card = cardView(); let header = UIButton(type: .system); header.contentHorizontalAlignment = .leading
        header.setTitle("Yaklaşan İşlemler  ›", for: .normal); header.titleLabel?.font = .preferredFont(forTextStyle: .headline); header.addTarget(self, action: #selector(remindersTapped), for: .touchUpInside)
        var views: [UIView] = [header]
        if reminders.isEmpty { views.append(infoLabel("Yaklaşan hatırlatma yok.", color: UIColor(named: "SecondaryText"))) }
        else { views += reminders.prefix(3).map { infoLabel("• \($0.title) — \($0.status.displayName)", color: $0.status == .overdue ? .systemRed : nil) } }
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

    private func cardView() -> UIView { let view = UIView(); view.backgroundColor = UIColor(named: "CardBackground"); view.layer.cornerRadius = AppTheme.cardCornerRadius; return view }
    private func install(_ stack: UIStackView, in card: UIView) { card.addSubview(stack); stack.pinToEdges(of: card, insets: NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) }
    private func label(_ text: String, style: UIFont.TextStyle, weight: UIFont.Weight) -> UILabel { let label = UILabel(); label.text = text; label.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight); label.adjustsFontForContentSizeCategory = true; label.numberOfLines = 0; return label }
    private func infoLabel(_ text: String, color: UIColor?) -> UILabel { let label = UILabel(); label.text = text; label.font = .preferredFont(forTextStyle: .body); label.adjustsFontForContentSizeCategory = true; label.textColor = color; label.numberOfLines = 0; return label }

    @objc private func settings() { onSettings?() }
    @objc private func chooseVehicle() { onChooseVehicle?() }
    @objc private func updateMileage() { onUpdateMileage?() }
    @objc private func remindersTapped() { onReminders?() }
    @objc private func quickAction(_ sender: UIButton) { guard RecordType.allCases.indices.contains(sender.tag) else { return }; onAddRecord?(RecordType.allCases[sender.tag]) }
    @objc private func reload() { Task { await viewModel.load() } }
    @objc private func refresh(_ control: UIRefreshControl) { Task { await viewModel.load(); control.endRefreshing() } }
}

private extension UIStackView {
    static func vertical(_ views: [UIView], spacing: CGFloat) -> UIStackView { let stack = UIStackView(arrangedSubviews: views); stack.axis = .vertical; stack.spacing = spacing; return stack }
}
