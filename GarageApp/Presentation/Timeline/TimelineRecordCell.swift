//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

enum RecordVisualStyle {
    static func tint(for type: RecordType) -> UIColor {
        type.tintColor
    }

    static func symbol(for record: VehicleRecord) -> String {
        if record.recordType == .expense,
           record.title.localizedCaseInsensitiveContains("otopark") {
            return "parkingsign.circle"
        }
        return record.recordType.symbolName
    }

    static func currency(_ amount: Decimal?) -> String? {
        guard let amount else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let value = formatter.string(from: amount as NSDecimalNumber) ?? String(describing: amount)
        return "\(value) ₺"
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    static func mileage(_ value: Int64) -> String {
        let formatted = AppFormatters.mileage.string(from: NSNumber(value: value)) ?? String(value)
        return "\(formatted) km"
    }

    static func detailTitle(for type: RecordType) -> String {
        switch type {
        case .maintenance: "Bakım Detayı"
        case .fuel: "Yakıt Detayı"
        case .expense: "Masraf Detayı"
        case .insurance: "Sigorta Detayı"
        case .inspection: "Muayene Detayı"
        case .mileage: "Kilometre Detayı"
        case .note: "Not Detayı"
        }
    }
}

final class TimelineRecordCell: UITableViewCell {
    static let reuseIdentifier = "TimelineRecordCell"

    @IBOutlet private weak var topRailView: UIView!
    @IBOutlet private weak var bottomRailView: UIView!
    @IBOutlet private weak var nodeView: UIView!
    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var metadataLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var attachmentImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        isAccessibilityElement = true

        AppTheme.styleCard(cardView)
        topRailView.backgroundColor = AppTheme.borderColor
        bottomRailView.backgroundColor = AppTheme.borderColor
        nodeView.backgroundColor = AppTheme.backgroundColor
        nodeView.layer.cornerRadius = 6
        nodeView.layer.cornerCurve = .continuous
        nodeView.layer.borderWidth = 2
        updateNodeBorder()
        nodeView.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            view.layer.borderColor = AppTheme.borderColor.resolvedColor(with: view.traitCollection).cgColor
        }

        iconContainerView.layer.cornerRadius = 25
        iconContainerView.layer.cornerCurve = .continuous
        iconImageView.contentMode = .scaleAspectFit

        titleLabel.font = AppTheme.font(.body, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        metadataLabel.font = AppTheme.font(.subheadline)
        metadataLabel.textColor = AppTheme.secondaryTextColor
        metadataLabel.adjustsFontForContentSizeCategory = true
        amountLabel.font = AppTheme.font(.body, weight: .medium)
        amountLabel.textColor = AppTheme.primaryTextColor
        amountLabel.adjustsFontForContentSizeCategory = true
        attachmentImageView.tintColor = AppTheme.secondaryTextColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        metadataLabel.text = nil
        amountLabel.text = nil
        amountLabel.isHidden = false
        attachmentImageView.isHidden = true
        cardView.transform = .identity
        cardView.alpha = 1
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let changes = {
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
            self.cardView.alpha = highlighted ? 0.78 : 1
        }
        animated ? UIView.animate(withDuration: 0.16, animations: changes) : changes()
    }

    func configure(record: VehicleRecord, hasDocument: Bool, isFirst: Bool, isLast: Bool) {
        let tint = RecordVisualStyle.tint(for: record.recordType)
        iconContainerView.backgroundColor = tint.withAlphaComponent(0.13)
        iconImageView.tintColor = tint
        iconImageView.image = UIImage(systemName: RecordVisualStyle.symbol(for: record))
        titleLabel.text = record.title
        amountLabel.text = RecordVisualStyle.currency(record.totalAmount)
        amountLabel.isHidden = record.totalAmount == nil
        attachmentImageView.isHidden = !hasDocument
        topRailView.isHidden = isFirst
        bottomRailView.isHidden = isLast

        var metadata = [RecordVisualStyle.shortDate(record.eventDate)]
        if let odometer = record.odometer { metadata.append(RecordVisualStyle.mileage(odometer)) }
        metadataLabel.text = metadata.joined(separator: "  •  ")

        var accessibilityParts = [record.title, record.recordType.displayName, metadata.joined(separator: ", ")]
        if let amount = RecordVisualStyle.currency(record.totalAmount) { accessibilityParts.append(amount) }
        if hasDocument { accessibilityParts.append("Belge ekli") }
        accessibilityLabel = accessibilityParts.joined(separator: ", ")
        accessibilityHint = "Kayıt detayını açar"
        accessibilityTraits = .button
    }

    private func updateNodeBorder() {
        nodeView.layer.borderColor = AppTheme.borderColor.resolvedColor(with: traitCollection).cgColor
    }
}

final class TimelineMonthHeaderView: UIView {
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppTheme.backgroundColor
        titleLabel.font = AppTheme.font(.subheadline, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AppTheme.Metrics.horizontalMargin),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -AppTheme.Metrics.horizontalMargin),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 6)
        ])
    }

    func configure(title: String) {
        titleLabel.text = title
        accessibilityLabel = title
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}
