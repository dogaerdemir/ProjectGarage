//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

final class RecordDetailHeroView: UIView {
    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var categoryContainerView: UIView!
    @IBOutlet private weak var categoryLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!

    static func instantiate() -> RecordDetailHeroView {
        guard let view = UINib(nibName: "RecordDetailHeroView", bundle: .main)
            .instantiate(withOwner: nil)
            .first as? RecordDetailHeroView else {
            preconditionFailure("RecordDetailHeroView.xib could not be loaded")
        }
        return view
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.backgroundColor
        AppTheme.styleCard(cardView)

        iconContainerView.layer.cornerRadius = 28
        iconContainerView.layer.cornerCurve = .continuous
        categoryContainerView.layer.cornerRadius = 7
        categoryContainerView.layer.cornerCurve = .continuous

        titleLabel.font = AppTheme.font(.title3, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header
        categoryLabel.font = AppTheme.font(.caption1, weight: .medium)
        categoryLabel.adjustsFontForContentSizeCategory = true
        amountLabel.font = AppTheme.font(.title3, weight: .semibold)
        amountLabel.textColor = AppTheme.primaryTextColor
        amountLabel.adjustsFontForContentSizeCategory = true
    }

    func configure(record: VehicleRecord) {
        let tint = RecordVisualStyle.tint(for: record.recordType)
        iconContainerView.backgroundColor = tint.withAlphaComponent(0.13)
        iconImageView.tintColor = tint
        iconImageView.image = UIImage(systemName: RecordVisualStyle.symbol(for: record))
        titleLabel.text = record.title
        categoryContainerView.backgroundColor = tint.withAlphaComponent(0.14)
        categoryLabel.textColor = tint
        categoryLabel.text = record.recordType.displayName
        amountLabel.text = RecordVisualStyle.currency(record.totalAmount)
        amountLabel.isHidden = record.totalAmount == nil

        var parts = [record.title, record.recordType.displayName]
        if let amount = RecordVisualStyle.currency(record.totalAmount) { parts.append(amount) }
        cardView.isAccessibilityElement = true
        cardView.accessibilityLabel = parts.joined(separator: ", ")
    }
}
