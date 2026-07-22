//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class InsightsViewController: UIViewController {
    var viewModel: InsightsViewModel!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = AppTheme.backgroundColor
        view.subviews.forEach { $0.removeFromSuperview() }

        configureLayout()
        viewModel.onChange = { [weak self] in self?.render($0) }
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        Task { await viewModel.load() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureLayout() {
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.pinToEdges(of: view)

        stack.axis = .vertical
        stack.spacing = AppTheme.Spacing.standard
        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AppTheme.horizontalSpacing),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AppTheme.horizontalSpacing),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppTheme.horizontalSpacing),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.large),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(AppTheme.horizontalSpacing * 2))
        ])
    }

    private func render(_ state: InsightsViewModel.State) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let pageHeader = PageHeaderView(
                title: "İstatistikler",
                message: "Aracınızın maliyetlerini dönem ve kategori bazında inceleyin.",
                horizontalInset: 0
        )
        stack.addArrangedSubview(pageHeader)
        stack.setCustomSpacing(AppTheme.Spacing.small, after: pageHeader)

        guard let summary = state.summary else {
            stack.addArrangedSubview(
                EmptyStateView(
                    symbol: "chart.bar.fill",
                    title: "Yeterli veri yok",
                    message: state.error ?? "İstatistikler kayıt ekledikçe burada görünür."
                )
            )
            return
        }

        let formatter = AppFormatters.currency
        let metrics: [(String, Decimal)] = [
            ("Bu ay", summary.monthlyTotal),
            ("Bu yıl", summary.yearlyTotal),
        ] + RecordType.costChartTypes.map { type in
            (type.displayName, summary.totalsByType[type] ?? 0)
        }

        let summarySection = UIStackView()
        summarySection.axis = .vertical
        summarySection.spacing = AppTheme.Spacing.medium
        summarySection.addArrangedSubview(
            sectionHeader(
                title: "Harcama Özeti",
                message: "Seçili aracınızın güncel maliyet görünümü"
            )
        )
        summarySection.setCustomSpacing(AppTheme.Spacing.standard, after: summarySection.arrangedSubviews[0])
        summarySection.addArrangedSubview(metricGrid(metrics, formatter: formatter))

        if let cost = summary.costPerKilometer {
            summarySection.addArrangedSubview(
                metricCard(
                    "Kilometre başına maliyet",
                    formatter.string(from: cost as NSDecimalNumber) ?? "—"
                )
            )
        }

        stack.addArrangedSubview(summarySection)
        stack.addArrangedSubview(chartCard(values: state.chartValues))
    }

    private func metricGrid(_ metrics: [(String, Decimal)], formatter: NumberFormatter) -> UIView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12

        let usesSingleColumn = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        var index = 0
        while index < metrics.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .fill
            row.distribution = .fillEqually
            row.spacing = 12

            let first = metrics[index]
            row.addArrangedSubview(
                metricCard(
                    first.0,
                    formatter.string(from: first.1 as NSDecimalNumber) ?? "—"
                )
            )
            index += 1

            if !usesSingleColumn, index < metrics.count {
                let second = metrics[index]
                row.addArrangedSubview(
                    metricCard(
                        second.0,
                        formatter.string(from: second.1 as NSDecimalNumber) ?? "—"
                    )
                )
                index += 1
            }

            grid.addArrangedSubview(row)
        }
        return grid
    }

    private func sectionHeader(title: String, message: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.font(.title3, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = AppTheme.font(.subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = AppTheme.secondaryTextColor
        messageLabel.numberOfLines = 0

        let header = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        header.axis = .vertical
        header.spacing = 4
        return header
    }

    private func metricCard(_ title: String, _ value: String) -> UIView {
        let card = UIView()
        AppTheme.styleBorderedSurface(card, backgroundColor: AppTheme.surfaceColor)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.font(.subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.secondaryTextColor
        titleLabel.numberOfLines = 0

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AppTheme.font(.title3, weight: .semibold)
        valueLabel.textColor = AppTheme.primaryTextColor
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0

        let content = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        content.axis = .vertical
        content.spacing = AppTheme.Spacing.small
        card.addSubview(content)
        content.pinToEdges(
            of: card,
            insets: NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        )

        card.isAccessibilityElement = true
        card.accessibilityLabel = "\(title), \(value)"
        return card
    }

    private func chartCard(values: [MonthlyCostChartEntry]) -> UIView {
        let card = UIView()
        AppTheme.styleCard(card)

        let titleLabel = UILabel()
        titleLabel.text = "Son 12 Ayın Giderleri"
        titleLabel.font = AppTheme.font(.title3, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        let messageLabel = UILabel()
        messageLabel.text = "Aylık toplamlar ve kategori dağılımı"
        messageLabel.font = AppTheme.font(.subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = AppTheme.secondaryTextColor
        messageLabel.numberOfLines = 0

        let header = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        header.axis = .vertical
        header.spacing = 4

        let chart = MonthlyBarChartView()
        chart.heightAnchor.constraint(
            equalToConstant: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 310 : 270
        ).isActive = true

        let detailView = ChartMonthDetailView()
        chart.onSelection = { [weak detailView] entry in
            detailView?.configure(with: entry)
        }
        chart.values = values

        let legendTitle = UILabel()
        legendTitle.text = "Kategoriler"
        legendTitle.font = AppTheme.font(.footnote, weight: .semibold)
        legendTitle.textColor = AppTheme.secondaryTextColor
        legendTitle.adjustsFontForContentSizeCategory = true

        let legend = chartLegend()
        let legendSection = UIStackView(arrangedSubviews: [legendTitle, legend])
        legendSection.axis = .vertical
        legendSection.spacing = 8

        let content = UIStackView(arrangedSubviews: [header, chart, detailView, legendSection])
        content.axis = .vertical
        content.spacing = AppTheme.Spacing.standard
        card.addSubview(content)
        content.pinToEdges(
            of: card,
            insets: NSDirectionalEdgeInsets(
                top: AppTheme.Metrics.cardPadding,
                leading: AppTheme.Metrics.cardPadding,
                bottom: AppTheme.Metrics.cardPadding,
                trailing: AppTheme.Metrics.cardPadding
            )
        )
        return card
    }

    private func chartLegend() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        var index = 0
        while index < RecordType.costChartTypes.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 12
            row.addArrangedSubview(legendItem(for: RecordType.costChartTypes[index]))
            index += 1

            if index < RecordType.costChartTypes.count {
                row.addArrangedSubview(legendItem(for: RecordType.costChartTypes[index]))
                index += 1
            } else {
                row.addArrangedSubview(UIView())
            }
            container.addArrangedSubview(row)
        }
        return container
    }

    private func legendItem(for type: RecordType) -> UIView {
        let dot = UIView()
        dot.backgroundColor = type.tintColor
        dot.layer.cornerRadius = 5
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let label = UILabel()
        label.text = type.displayName
        label.font = AppTheme.font(.footnote)
        label.textColor = AppTheme.primaryTextColor
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        let item = UIStackView(arrangedSubviews: [dot, label])
        item.axis = .horizontal
        item.alignment = .center
        item.spacing = 7
        item.isAccessibilityElement = true
        item.accessibilityLabel = type.displayName
        return item
    }

    @objc private func reload() {
        Task { await viewModel.load() }
    }

    @objc private func contentSizeCategoryDidChange() {
        render(viewModel.state)
    }
}

final class MonthlyBarChartView: UIView {
    var values: [MonthlyCostChartEntry] = [] {
        didSet {
            let initialIndex = values.lastIndex { $0.total > 0 } ?? values.indices.last
            select(index: initialIndex)
            setNeedsDisplay()
        }
    }

    var onSelection: ((MonthlyCostChartEntry?) -> Void)?
    private var selectedIndex: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = [.image, .adjustable]
        accessibilityLabel = "Aylık harcama grafiği"
        accessibilityHint = "Aylar arasında gezinmek için yukarı veya aşağı kaydırın. Bir aya dokunarak ayrıntısını görüntüleyin."
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chartTapped(_:))))
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self]) { (chart: MonthlyBarChartView, _) in
            chart.setNeedsDisplay()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func accessibilityIncrement() {
        guard !values.isEmpty else { return }
        select(index: min((selectedIndex ?? -1) + 1, values.count - 1))
    }

    override func accessibilityDecrement() {
        guard !values.isEmpty else { return }
        select(index: max((selectedIndex ?? values.count) - 1, 0))
    }

    override func draw(_ rect: CGRect) {
        guard !values.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }

        let geometry = chartGeometry(in: rect)
        let maximumValue = values.map { decimalDouble($0.total) }.max() ?? 0
        let axisMaximum = roundedAxisMaximum(maximumValue)
        drawYAxis(in: geometry.chartRect, maximum: axisMaximum, context: context)
        drawMonths(in: geometry, maximum: axisMaximum, context: context)

        if maximumValue == 0 {
            let text = "Son 12 ayda harcama kaydı yok"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: AppTheme.font(.footnote, weight: .medium),
                .foregroundColor: AppTheme.secondaryTextColor
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: geometry.chartRect.midX - size.width / 2, y: geometry.chartRect.midY - size.height / 2),
                withAttributes: attributes
            )
        }
    }

    @objc private func chartTapped(_ recognizer: UITapGestureRecognizer) {
        guard !values.isEmpty else { return }
        let geometry = chartGeometry(in: bounds)
        let point = recognizer.location(in: self)
        guard point.x >= geometry.chartRect.minX, point.x <= geometry.chartRect.maxX else { return }
        let rawIndex = Int((point.x - geometry.chartRect.minX) / geometry.slotWidth)
        select(index: min(max(rawIndex, 0), values.count - 1))
    }

    private func select(index: Int?) {
        guard let index, values.indices.contains(index) else {
            selectedIndex = nil
            accessibilityValue = nil
            onSelection?(nil)
            setNeedsDisplay()
            return
        }

        selectedIndex = index
        let entry = values[index]
        let total = AppFormatters.currency.string(from: entry.total as NSDecimalNumber) ?? "\(entry.total)"
        let breakdown = RecordType.costChartTypes.compactMap { type -> String? in
            guard let amount = entry.amountsByType[type], amount > 0 else { return nil }
            let value = AppFormatters.currency.string(from: amount as NSDecimalNumber) ?? "\(amount)"
            return "\(type.displayName) \(value)"
        }
        accessibilityValue = ([entry.fullLabel, "Toplam \(total)"] + breakdown).joined(separator: ", ")
        onSelection?(entry)
        setNeedsDisplay()
    }

    private func chartGeometry(in rect: CGRect) -> (chartRect: CGRect, slotWidth: CGFloat, labelFont: UIFont) {
        let labelFont = AppTheme.font(.caption2)
        let contentRect = rect.insetBy(dx: 4, dy: 8)
        let yAxisWidth: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 64 : 52
        let xAxisHeight = labelFont.lineHeight + 12
        let chartRect = CGRect(
            x: contentRect.minX + yAxisWidth,
            y: contentRect.minY + 4,
            width: max(0, contentRect.width - yAxisWidth),
            height: max(0, contentRect.height - xAxisHeight - 4)
        )
        return (chartRect, chartRect.width / CGFloat(max(values.count, 1)), labelFont)
    }

    private func drawYAxis(in chartRect: CGRect, maximum: Double, context: CGContext) {
        let lineColor = AppTheme.borderColor.withAlphaComponent(0.8)
        let textColor = AppTheme.secondaryTextColor
        let labelFont = AppTheme.font(.caption2)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]

        for step in 0...4 {
            let ratio = CGFloat(step) / 4
            let y = chartRect.maxY - chartRect.height * ratio
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(1 / max(UIScreen.main.scale, 1))
            context.move(to: CGPoint(x: chartRect.minX, y: y))
            context.addLine(to: CGPoint(x: chartRect.maxX, y: y))
            context.strokePath()

            let value = maximum * Double(step) / 4
            let text = compactCurrency(value)
            text.draw(
                in: CGRect(x: 0, y: y - labelFont.lineHeight / 2, width: chartRect.minX - 8, height: labelFont.lineHeight + 2),
                withAttributes: attributes
            )
        }
    }

    private func drawMonths(
        in geometry: (chartRect: CGRect, slotWidth: CGFloat, labelFont: UIFont),
        maximum: Double,
        context: CGContext
    ) {
        let barWidth = max(6, geometry.slotWidth * 0.58)
        let labelInterval = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 3 : 2
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: geometry.labelFont,
            .foregroundColor: AppTheme.secondaryTextColor
        ]

        for (index, entry) in values.enumerated() {
            let x = geometry.chartRect.minX + CGFloat(index) * geometry.slotWidth + (geometry.slotWidth - barWidth) / 2
            let totalHeight = maximum > 0 ? geometry.chartRect.height * CGFloat(decimalDouble(entry.total) / maximum) : 0
            let barRect = CGRect(x: x, y: geometry.chartRect.maxY - totalHeight, width: barWidth, height: totalHeight)

            if index == selectedIndex {
                let highlight = CGRect(
                    x: geometry.chartRect.minX + CGFloat(index) * geometry.slotWidth + 1,
                    y: geometry.chartRect.minY,
                    width: max(0, geometry.slotWidth - 2),
                    height: geometry.chartRect.height
                )
                AppTheme.accentSoftColor.withAlphaComponent(0.55).setFill()
                UIBezierPath(roundedRect: highlight, cornerRadius: 8).fill()
            }

            if totalHeight > 0 {
                context.saveGState()
                UIBezierPath(roundedRect: barRect, cornerRadius: min(5, barWidth / 2)).addClip()
                var currentY = geometry.chartRect.maxY
                for type in RecordType.costChartTypes {
                    let amount = decimalDouble(entry.amountsByType[type] ?? 0)
                    guard amount > 0 else { continue }
                    let segmentHeight = geometry.chartRect.height * CGFloat(amount / maximum)
                    currentY -= segmentHeight
                    context.setFillColor(type.tintColor.cgColor)
                    context.fill(CGRect(x: x, y: currentY, width: barWidth, height: segmentHeight + 0.5))
                }
                context.restoreGState()
            }

            guard index % labelInterval == 0 || index == selectedIndex else { continue }
            let labelSize = entry.shortLabel.size(withAttributes: labelAttributes)
            entry.shortLabel.draw(
                at: CGPoint(
                    x: x + (barWidth - labelSize.width) / 2,
                    y: geometry.chartRect.maxY + 7
                ),
                withAttributes: labelAttributes
            )
        }
    }

    private func roundedAxisMaximum(_ value: Double) -> Double {
        guard value > 0 else { return 1 }
        let magnitude = pow(10, floor(log10(value)))
        let normalized = value / magnitude
        let rounded: Double
        switch normalized {
        case ...1: rounded = 1
        case ...2: rounded = 2
        case ...5: rounded = 5
        default: rounded = 10
        }
        return rounded * magnitude
    }

    private func compactCurrency(_ value: Double) -> String {
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
        return "₺\(number)\(suffix)"
    }

    private func decimalDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private final class ChartMonthDetailView: UIView {
    private let titleLabel = UILabel()
    private let totalLabel = UILabel()
    private let rowsStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        AppTheme.styleBorderedSurface(self, backgroundColor: AppTheme.inputColor)

        titleLabel.font = AppTheme.font(.subheadline, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        totalLabel.font = AppTheme.font(.title3, weight: .semibold)
        totalLabel.textColor = AppTheme.accentColor
        totalLabel.adjustsFontForContentSizeCategory = true
        totalLabel.numberOfLines = 0
        totalLabel.textAlignment = .left

        let header = UIStackView(arrangedSubviews: [titleLabel, totalLabel])
        header.axis = .vertical
        header.alignment = .fill
        header.spacing = AppTheme.Spacing.xSmall

        rowsStack.axis = .vertical
        rowsStack.spacing = 7

        let content = UIStackView(arrangedSubviews: [header, rowsStack])
        content.axis = .vertical
        content.spacing = 12
        addSubview(content)
        content.pinToEdges(
            of: self,
            insets: NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        )
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func configure(with entry: MonthlyCostChartEntry?) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let entry else {
            titleLabel.text = "Ay seçin"
            totalLabel.text = nil
            addEmptyMessage("Kategori dağılımını görmek için grafikte bir aya dokunun.")
            return
        }

        titleLabel.text = entry.fullLabel
        totalLabel.text = AppFormatters.currency.string(from: entry.total as NSDecimalNumber) ?? "—"
        let populatedTypes = RecordType.costChartTypes.filter { (entry.amountsByType[$0] ?? 0) > 0 }
        guard !populatedTypes.isEmpty else {
            addEmptyMessage("Bu ay harcama kaydı yok.")
            return
        }

        populatedTypes.forEach { type in
            let amount = entry.amountsByType[type] ?? 0
            let formattedAmount = AppFormatters.currency.string(from: amount as NSDecimalNumber) ?? "—"
            rowsStack.addArrangedSubview(detailRow(type: type, value: formattedAmount))
        }
    }

    private func detailRow(type: RecordType, value: String) -> UIView {
        let dot = UIView()
        dot.backgroundColor = type.tintColor
        dot.layer.cornerRadius = 5
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let nameLabel = UILabel()
        nameLabel.text = type.displayName
        nameLabel.font = AppTheme.font(.footnote)
        nameLabel.textColor = AppTheme.secondaryTextColor
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AppTheme.font(.footnote, weight: .semibold)
        valueLabel.textColor = AppTheme.primaryTextColor
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .left

        let labels = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
        labels.axis = .vertical
        labels.spacing = AppTheme.Spacing.xxSmall

        let row = UIStackView(arrangedSubviews: [dot, labels])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 8
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(type.displayName), \(value)"
        return row
    }

    private func addEmptyMessage(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.font(.footnote)
        label.textColor = AppTheme.secondaryTextColor
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        rowsStack.addArrangedSubview(label)
    }
}
