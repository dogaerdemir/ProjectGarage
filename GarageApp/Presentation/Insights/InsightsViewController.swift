//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class InsightsViewController: UIViewController {
    var viewModel: InsightsViewModel!
    private let scrollView = UIScrollView(); private let stack = UIStackView()
    override func viewDidLoad() {
        super.viewDidLoad(); title = "İstatistikler"; view.backgroundColor = UIColor(named: "AppBackground"); view.subviews.forEach { $0.removeFromSuperview() }
        view.addSubview(scrollView); scrollView.pinToEdges(of: view); stack.axis = .vertical; stack.spacing = 16; scrollView.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16), stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16), stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16), stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24), stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)])
        viewModel.onChange = { [weak self] in self?.render($0) }; NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil); NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil); Task { await viewModel.load() }
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    private func render(_ state: InsightsViewModel.State) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }; guard let summary = state.summary else { stack.addArrangedSubview(EmptyStateView(symbol: "chart.bar.fill", title: "Yeterli veri yok", message: state.error ?? "İstatistikler kayıt ekledikçe burada görünür.")); return }
        let formatter = AppFormatters.currency; let metrics: [(String, Decimal)] = [("Bu ay", summary.monthlyTotal), ("Bu yıl", summary.yearlyTotal), ("Yakıt", summary.fuelTotal), ("Bakım", summary.maintenanceTotal), ("Diğer", summary.otherTotal)]
        let grid = UIStackView(); grid.axis = .vertical; grid.spacing = 10
        for pair in stride(from: 0, to: metrics.count, by: 2) { let row = UIStackView(); row.distribution = .fillEqually; row.spacing = 10; row.addArrangedSubview(metricCard(metrics[pair].0, formatter.string(from: metrics[pair].1 as NSDecimalNumber) ?? "—")); if pair + 1 < metrics.count { row.addArrangedSubview(metricCard(metrics[pair + 1].0, formatter.string(from: metrics[pair + 1].1 as NSDecimalNumber) ?? "—")) } else { row.addArrangedSubview(UIView()) }; grid.addArrangedSubview(row) }
        stack.addArrangedSubview(grid)
        if let cost = summary.costPerKilometer { stack.addArrangedSubview(metricCard("Kilometre başına maliyet", formatter.string(from: cost as NSDecimalNumber) ?? "—")) }
        let chartCard = UIView(); chartCard.backgroundColor = UIColor(named: "CardBackground"); chartCard.layer.cornerRadius = AppTheme.cardCornerRadius
        let chartTitle = UILabel(); chartTitle.text = "Son 12 Ayın Giderleri"; chartTitle.font = .preferredFont(forTextStyle: .headline)
        let chart = MonthlyBarChartView(); chart.values = state.chartValues; chart.heightAnchor.constraint(equalToConstant: 230).isActive = true
        let chartStack = UIStackView(arrangedSubviews: [chartTitle, chart]); chartStack.axis = .vertical; chartStack.spacing = 12; chartCard.addSubview(chartStack); chartStack.pinToEdges(of: chartCard, insets: NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)); stack.addArrangedSubview(chartCard)
    }
    private func metricCard(_ title: String, _ value: String) -> UIView { let card = UIView(); card.backgroundColor = UIColor(named: "CardBackground"); card.layer.cornerRadius = AppTheme.cardCornerRadius; let titleLabel = UILabel(); titleLabel.text = title; titleLabel.font = .preferredFont(forTextStyle: .subheadline); titleLabel.textColor = UIColor(named: "SecondaryText"); let valueLabel = UILabel(); valueLabel.text = value; valueLabel.font = .preferredFont(forTextStyle: .headline); valueLabel.adjustsFontForContentSizeCategory = true; valueLabel.numberOfLines = 1; valueLabel.minimumScaleFactor = 0.7; valueLabel.adjustsFontSizeToFitWidth = true; let inner = UIStackView(arrangedSubviews: [titleLabel, valueLabel]); inner.axis = .vertical; inner.spacing = 6; card.addSubview(inner); inner.pinToEdges(of: card, insets: NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)); return card }
    @objc private func reload() { Task { await viewModel.load() } }
}

final class MonthlyBarChartView: UIView {
    var values: [(String, Decimal)] = [] { didSet { setNeedsDisplay(); accessibilityLabel = values.map { "\($0.0): \($0.1)" }.joined(separator: ", ") } }
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isAccessibilityElement = true; accessibilityTraits = .image }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        guard !values.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        let maxValue = values.map { NSDecimalNumber(decimal: $0.1).doubleValue }.max() ?? 0; guard maxValue > 0 else { return }
        let labelHeight: CGFloat = 24, chartRect = rect.insetBy(dx: 8, dy: 8).divided(atDistance: rect.height - labelHeight, from: .minYEdge).slice
        let slot = chartRect.width / CGFloat(values.count); let barWidth = max(5, slot * 0.55); context.setFillColor((UIColor(named: "AppAccent") ?? .systemBlue).cgColor)
        for (index, item) in values.enumerated() { let ratio = NSDecimalNumber(decimal: item.1).doubleValue / maxValue; let height = chartRect.height * CGFloat(ratio); let x = chartRect.minX + CGFloat(index) * slot + (slot - barWidth) / 2; let bar = UIBezierPath(roundedRect: CGRect(x: x, y: chartRect.maxY - height, width: barWidth, height: height), cornerRadius: min(5, barWidth / 2)); bar.fill(); if index % 2 == 0 { let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: .caption2), .foregroundColor: UIColor.secondaryLabel]; item.0.draw(at: CGPoint(x: x - 3, y: chartRect.maxY + 5), withAttributes: attributes) } }
    }
}
