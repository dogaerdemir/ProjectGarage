//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class InsightsViewController: UIViewController {
    var viewModel: InsightsViewModel!

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = AppTheme.backgroundColor
        view.subviews.forEach { $0.removeFromSuperview() }

        configureLayout()
        viewModel.onChange = { [weak self] state in self?.render(state) }
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        render(viewModel.state)
        Task { await viewModel.load() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureLayout() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .always
        view.addSubview(scrollView)
        scrollView.pinToEdges(of: view)

        contentStack.axis = .vertical
        contentStack.spacing = AppTheme.Metrics.pageSectionSpacing
        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                constant: AppTheme.Metrics.horizontalMargin
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                constant: -AppTheme.Metrics.horizontalMargin
            ),
            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: AppTheme.Metrics.pageTopInset
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -AppTheme.Metrics.pageBottomInset
            ),
            contentStack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                constant: -(AppTheme.Metrics.horizontalMargin * 2)
            )
        ])
    }

    private func render(_ state: InsightsViewModel.State) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(pageTitle())
        contentStack.setCustomSpacing(
            AppTheme.Metrics.pageTitleToContentSpacing,
            after: contentStack.arrangedSubviews[0]
        )

        if state.isLoading, !state.hasVehicle {
            let loadingView = LoadingView()
            loadingView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
            contentStack.addArrangedSubview(loadingView)
            return
        }

        guard state.hasVehicle else {
            contentStack.addArrangedSubview(
                EmptyStateView(
                    symbol: "chart.bar.fill",
                    title: "Yeterli veri yok",
                    message: state.error ?? "İstatistikler kayıt ekledikçe burada görünür."
                )
            )
            return
        }

        contentStack.addArrangedSubview(periodControl(selectedPeriod: state.selectedPeriod))
        contentStack.addArrangedSubview(totalCard(total: state.total))
        contentStack.addArrangedSubview(
            supportingMetrics(
                costPerKilometer: state.costPerKilometer,
                distance: state.distance
            )
        )

        let distributionTitle = sectionTitle("Dağılım")
        contentStack.addArrangedSubview(distributionTitle)
        contentStack.setCustomSpacing(AppTheme.Metrics.sectionTitleToContentSpacing, after: distributionTitle)
        contentStack.addArrangedSubview(distributionCard(totals: state.categoryTotals))

        let chartTitle = sectionTitle("Son 12 Ay")
        contentStack.addArrangedSubview(chartTitle)
        contentStack.setCustomSpacing(AppTheme.Metrics.sectionTitleToContentSpacing, after: chartTitle)
        contentStack.addArrangedSubview(chartCard(values: state.chartValues))
    }

    private func pageTitle() -> UILabel {
        let label = UILabel()
        label.text = "İstatistikler"
        AppTheme.stylePageTitle(label)
        return label
    }

    private func periodControl(selectedPeriod: InsightsPeriod) -> UISegmentedControl {
        let control = UISegmentedControl(items: ["Bu Ay", "Bu Yıl"])
        control.selectedSegmentIndex = selectedPeriod.rawValue
        AppTheme.styleSegmentedControl(control)
        AppTheme.styleBorderedSurface(
            control,
            backgroundColor: AppTheme.inputColor,
            cornerRadius: AppTheme.Radius.compact
        )
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        control.accessibilityLabel = "İstatistik dönemi"
        control.addTarget(self, action: #selector(periodChanged(_:)), for: .valueChanged)
        return control
    }

    private func totalCard(total: Decimal) -> UIView {
        let titleLabel = metricTitleLabel("Toplam Harcama")
        let valueLabel = UILabel()
        valueLabel.text = InsightsFormatters.currency(total, fractionDigits: 0)
        valueLabel.font = AppTheme.font(.title1, weight: .bold)
        valueLabel.textColor = AppTheme.accentColor
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        valueLabel.numberOfLines = 1

        let card = UIView()
        AppTheme.styleCard(card)
        install(
            verticalStack([titleLabel, valueLabel], spacing: AppTheme.Spacing.xSmall),
            in: card,
            insets: NSDirectionalEdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14)
        )
        card.isAccessibilityElement = true
        card.accessibilityLabel = "Toplam harcama, \(valueLabel.text ?? "")"
        return card
    }

    private func supportingMetrics(costPerKilometer: Decimal?, distance: Int64?) -> UIView {
        let costText = costPerKilometer.map { InsightsFormatters.currency($0, fractionDigits: 2) } ?? "—"
        let distanceText = distance.map { InsightsFormatters.distance($0) } ?? "—"
        let metrics = [
            compactMetricCard(title: "Kilometre Başına", value: costText),
            compactMetricCard(title: "Toplam Mesafe", value: distanceText)
        ]

        let stack = UIStackView(arrangedSubviews: metrics)
        let usesVerticalLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        stack.axis = usesVerticalLayout ? .vertical : .horizontal
        stack.distribution = usesVerticalLayout ? .fill : .fillEqually
        stack.alignment = .fill
        stack.spacing = AppTheme.Spacing.medium
        return stack
    }

    private func compactMetricCard(title: String, value: String) -> UIView {
        let titleLabel = metricTitleLabel(title)
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AppTheme.font(.title3, weight: .bold)
        valueLabel.textColor = AppTheme.accentColor
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.72
        valueLabel.numberOfLines = 1

        let card = UIView()
        AppTheme.styleCard(card)
        install(
            verticalStack([titleLabel, valueLabel], spacing: AppTheme.Spacing.xSmall),
            in: card,
            insets: NSDirectionalEdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13)
        )
        card.isAccessibilityElement = true
        card.accessibilityLabel = "\(title), \(value)"
        return card
    }

    private func metricTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.font(.subheadline)
        label.textColor = AppTheme.secondaryTextColor
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        return label
    }

    private func sectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.font(.headline, weight: .semibold)
        label.textColor = AppTheme.primaryTextColor
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }

    private func distributionCard(totals: [InsightsCategoryTotal]) -> UIView {
        let card = UIView()
        AppTheme.styleCard(card)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        for (index, total) in totals.enumerated() {
            stack.addArrangedSubview(distributionRow(total))
            if index < totals.count - 1 {
                stack.addArrangedSubview(HairlineView())
            }
        }

        install(
            stack,
            in: card,
            insets: NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 12)
        )
        return card
    }

    private func distributionRow(_ total: InsightsCategoryTotal) -> UIView {
        let iconView = UIImageView(
            image: UIImage(
                systemName: total.category.symbolName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            )
        )
        iconView.tintColor = total.category.tintColor
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = total.category.title
        titleLabel.font = AppTheme.font(.body, weight: .medium)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1

        let amountLabel = UILabel()
        amountLabel.text = InsightsFormatters.currency(total.amount, fractionDigits: 0)
        amountLabel.font = AppTheme.font(.body, weight: .semibold)
        amountLabel.textColor = AppTheme.primaryTextColor
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.75
        amountLabel.textAlignment = .right
        amountLabel.numberOfLines = 1
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), amountLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = AppTheme.Spacing.medium
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(total.category.title), \(amountLabel.text ?? "")"
        return row
    }

    private func chartCard(values: [MonthlyCostChartEntry]) -> UIView {
        let chart = CompactMonthlyBarChartView()
        chart.values = values
        chart.heightAnchor.constraint(
            equalToConstant: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 178 : 130
        ).isActive = true

        var chartContent: [UIView] = [chart]
        if values.contains(where: { $0.total > 0 }) {
            let legend = UIStackView(
                arrangedSubviews: InsightsCostCategory.allCases.map { legendItem(for: $0) }
            )
            legend.axis = .horizontal
            legend.alignment = .center
            legend.distribution = .fillEqually
            legend.spacing = AppTheme.Spacing.xSmall
            chartContent.append(legend)
        }

        let card = UIView()
        AppTheme.styleCard(card)
        install(
            verticalStack(chartContent, spacing: 6),
            in: card,
            insets: NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        )
        return card
    }

    private func legendItem(for category: InsightsCostCategory) -> UIView {
        let dot = UIView()
        dot.backgroundColor = category.tintColor
        dot.layer.cornerRadius = 4
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let label = UILabel()
        label.text = category.title
        label.font = AppTheme.font(.caption2)
        label.textColor = AppTheme.secondaryTextColor
        label.adjustsFontForContentSizeCategory = true
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.numberOfLines = 1

        let item = UIStackView(arrangedSubviews: [dot, label])
        item.axis = .horizontal
        item.alignment = .center
        item.spacing = 5
        item.isAccessibilityElement = true
        item.accessibilityLabel = category.title
        return item
    }

    private func verticalStack(_ views: [UIView], spacing: CGFloat) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = spacing
        return stack
    }

    private func install(_ stack: UIStackView, in card: UIView, insets: NSDirectionalEdgeInsets) {
        card.addSubview(stack)
        stack.pinToEdges(of: card, insets: insets)
    }

    @objc private func periodChanged(_ sender: UISegmentedControl) {
        guard let period = InsightsPeriod(rawValue: sender.selectedSegmentIndex) else { return }
        viewModel.selectPeriod(period)
    }

    @objc private func reload() {
        Task { await viewModel.load() }
    }

    @objc private func contentSizeCategoryDidChange() {
        render(viewModel.state)
    }
}

private extension InsightsCostCategory {
    var tintColor: UIColor {
        switch self {
        case .fuel: RecordType.fuel.tintColor
        case .maintenance: RecordType.maintenance.tintColor
        case .insurance: RecordType.insurance.tintColor
        case .other: .systemGray
        }
    }
}

private enum InsightsFormatters {
    static func currency(_ value: Decimal, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let number = formatter.string(from: value as NSDecimalNumber) ?? "0"
        return "\(number) ₺"
    }

    static func distance(_ value: Int64) -> String {
        let number = AppFormatters.mileage.string(from: NSNumber(value: value)) ?? String(value)
        return "\(number) km"
    }
}

private final class CompactMonthlyBarChartView: UIView {
    var values: [MonthlyCostChartEntry] = [] {
        didSet {
            updateAccessibilityValue()
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .image
        accessibilityLabel = "Son 12 ayın gider grafiği"
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self]) { (chart: CompactMonthlyBarChartView, _) in
            chart.setNeedsDisplay()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let maximumValue = values.map { decimalDouble($0.total) }.max() ?? 0
        guard maximumValue > 0 else {
            drawEmptyMessage(in: rect.insetBy(dx: AppTheme.Spacing.standard, dy: AppTheme.Spacing.standard))
            return
        }

        let geometry = chartGeometry(in: rect)
        let scale = axisScale(for: maximumValue)
        drawAxis(in: geometry.chartRect, scale: scale, context: context)
        drawBars(in: geometry, maximum: scale.maximum, context: context)
    }

    private struct Geometry {
        let chartRect: CGRect
        let slotWidth: CGFloat
        let labelFont: UIFont
    }

    private struct AxisScale {
        let maximum: Double
        let step: Double
        let tickCount: Int
    }

    private func chartGeometry(in rect: CGRect) -> Geometry {
        let labelFont = AppTheme.font(.caption2)
        let contentRect = rect.insetBy(dx: 2, dy: 2)
        let yAxisWidth: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 38 : 30
        let xAxisHeight = labelFont.lineHeight + 7
        let chartRect = CGRect(
            x: contentRect.minX + yAxisWidth,
            y: contentRect.minY + 2,
            width: max(0, contentRect.width - yAxisWidth),
            height: max(0, contentRect.height - xAxisHeight - 2)
        )
        return Geometry(
            chartRect: chartRect,
            slotWidth: chartRect.width / CGFloat(max(values.count, 1)),
            labelFont: labelFont
        )
    }

    private func axisScale(for maximumValue: Double) -> AxisScale {
        guard maximumValue > 0 else {
            return AxisScale(maximum: 1, step: 1, tickCount: 1)
        }

        let roughStep = maximumValue / 4
        let magnitude = pow(10, floor(log10(roughStep)))
        let normalizedStep = roughStep / magnitude
        let normalizedCandidates: [Double] = [1, 2, 2.5, 5, 10]
        let selectedStep = normalizedCandidates.first(where: { $0 >= normalizedStep }) ?? 10
        let step = selectedStep * magnitude
        let maximum = ceil(maximumValue / step) * step
        let tickCount = max(1, Int(round(maximum / step)))
        return AxisScale(maximum: maximum, step: step, tickCount: tickCount)
    }

    private func drawAxis(in chartRect: CGRect, scale: AxisScale, context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: AppTheme.font(.caption2),
            .foregroundColor: AppTheme.secondaryTextColor,
            .paragraphStyle: paragraph
        ]

        for tick in 0...scale.tickCount {
            let value = scale.step * Double(tick)
            let ratio = CGFloat(value / scale.maximum)
            let y = chartRect.maxY - chartRect.height * ratio

            context.setStrokeColor(AppTheme.borderColor.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(1 / max(UIScreen.main.scale, 1))
            context.move(to: CGPoint(x: chartRect.minX, y: y))
            context.addLine(to: CGPoint(x: chartRect.maxX, y: y))
            context.strokePath()

            let text = compactNumber(value)
            text.draw(
                in: CGRect(
                    x: 0,
                    y: y - AppTheme.font(.caption2).lineHeight / 2,
                    width: chartRect.minX - 5,
                    height: AppTheme.font(.caption2).lineHeight + 2
                ),
                withAttributes: attributes
            )
        }
    }

    private func drawBars(in geometry: Geometry, maximum: Double, context: CGContext) {
        let barWidth = max(6, geometry.slotWidth * 0.54)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: geometry.labelFont,
            .foregroundColor: AppTheme.secondaryTextColor,
            .paragraphStyle: paragraph
        ]

        for (index, entry) in values.enumerated() {
            let slotX = geometry.chartRect.minX + CGFloat(index) * geometry.slotWidth
            let x = slotX + (geometry.slotWidth - barWidth) / 2
            let totalHeight = maximum > 0
                ? geometry.chartRect.height * CGFloat(decimalDouble(entry.total) / maximum)
                : 0
            let barRect = CGRect(
                x: x,
                y: geometry.chartRect.maxY - totalHeight,
                width: barWidth,
                height: totalHeight
            )

            if totalHeight > 0 {
                context.saveGState()
                UIBezierPath(
                    roundedRect: barRect,
                    cornerRadius: min(3, barWidth / 2)
                ).addClip()

                var currentY = geometry.chartRect.maxY
                for category in InsightsCostCategory.allCases {
                    let amount = decimalDouble(entry.amountsByCategory[category] ?? 0)
                    guard amount > 0 else { continue }
                    let segmentHeight = geometry.chartRect.height * CGFloat(amount / maximum)
                    currentY -= segmentHeight
                    context.setFillColor(category.tintColor.cgColor)
                    context.fill(
                        CGRect(
                            x: x,
                            y: currentY,
                            width: barWidth,
                            height: segmentHeight + 0.5
                        )
                    )
                }
                context.restoreGState()
            }

            entry.shortLabel.draw(
                in: CGRect(
                    x: slotX,
                    y: geometry.chartRect.maxY + 4,
                    width: geometry.slotWidth,
                    height: geometry.labelFont.lineHeight + 2
                ),
                withAttributes: labelAttributes
            )
        }
    }

    private func drawEmptyMessage(in chartRect: CGRect) {
        let text = "Son 12 ayda harcama kaydı yok"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        text.draw(
            in: CGRect(
                x: chartRect.minX,
                y: chartRect.midY - 10,
                width: chartRect.width,
                height: 20
            ),
            withAttributes: [
                .font: AppTheme.font(.footnote, weight: .medium),
                .foregroundColor: AppTheme.secondaryTextColor,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func compactNumber(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        let divisor: Double
        let suffix: String
        if value >= 1_000_000 {
            divisor = 1_000_000
            suffix = " Mn"
        } else if value >= 1_000 {
            divisor = 1_000
            suffix = " B"
        } else {
            divisor = 1
            suffix = ""
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = divisor == 1 ? 0 : 1
        let number = formatter.string(from: NSNumber(value: value / divisor)) ?? "0"
        return number + suffix
    }

    private func updateAccessibilityValue() {
        let populatedMonths = values.filter { $0.total > 0 }
        guard !populatedMonths.isEmpty else {
            accessibilityValue = "Son 12 ayda harcama kaydı yok"
            return
        }

        accessibilityValue = populatedMonths.map { entry in
            let total = InsightsFormatters.currency(entry.total, fractionDigits: 0)
            return "\(entry.fullLabel), \(total)"
        }.joined(separator: "; ")
    }

    private func decimalDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
