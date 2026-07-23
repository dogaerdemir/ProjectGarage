//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

final class RecordDetailRowCell: UITableViewCell {
    static let reuseIdentifier = "RecordDetailRowCell"

    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var valueLabel: UILabel!
    @IBOutlet private weak var chevronImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.surfaceColor
        contentView.backgroundColor = AppTheme.surfaceColor
        iconContainerView.layer.cornerRadius = AppTheme.Radius.compact
        iconContainerView.layer.cornerCurve = .continuous
        titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontForContentSizeCategory = true
        chevronImageView.tintColor = AppTheme.secondaryTextColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconContainerView.isHidden = true
        subtitleLabel.isHidden = true
        valueLabel.isHidden = false
        chevronImageView.isHidden = true
        titleLabel.text = nil
        subtitleLabel.text = nil
        valueLabel.text = nil
        selectionStyle = .none
        accessibilityHint = nil
        accessibilityTraits = .staticText
    }

    func configure(key: String, value: String) {
        iconContainerView.isHidden = true
        subtitleLabel.isHidden = true
        chevronImageView.isHidden = true
        valueLabel.isHidden = false
        titleLabel.text = key
        titleLabel.font = AppTheme.font(.body)
        titleLabel.textColor = AppTheme.primaryTextColor
        valueLabel.text = value
        valueLabel.font = AppTheme.font(.body, weight: .medium)
        valueLabel.textColor = AppTheme.primaryTextColor
        selectionStyle = .none
        accessibilityLabel = "\(key), \(value)"
        accessibilityHint = nil
        accessibilityTraits = .staticText
    }

    func configure(lineItem: RecordLineItem) {
        iconContainerView.isHidden = true
        titleLabel.text = lineItem.name
        titleLabel.font = AppTheme.font(.body, weight: .medium)
        titleLabel.textColor = AppTheme.primaryTextColor
        subtitleLabel.text = nil
        subtitleLabel.isHidden = true
        valueLabel.isHidden = false
        valueLabel.text = "1 Adet"
        valueLabel.font = AppTheme.font(.subheadline)
        valueLabel.textColor = AppTheme.secondaryTextColor
        chevronImageView.isHidden = false
        selectionStyle = .none
        accessibilityLabel = [lineItem.name, lineItem.category, "1 adet"].compactMap { $0 }.joined(separator: ", ")
        accessibilityHint = nil
        accessibilityTraits = .staticText
    }

    func configure(document: GarageDocument) {
        let isPDF = document.mimeType == "application/pdf"
        let tint = isPDF ? AppTheme.dangerColor : AppTheme.accentColor
        iconContainerView.isHidden = false
        iconContainerView.backgroundColor = tint.withAlphaComponent(0.10)
        iconImageView.tintColor = tint
        iconImageView.image = UIImage(systemName: isPDF ? "doc.text" : "photo")
        titleLabel.text = document.displayName
        titleLabel.font = AppTheme.font(.body, weight: .medium)
        titleLabel.textColor = AppTheme.primaryTextColor
        subtitleLabel.text = ByteCountFormatter.string(fromByteCount: document.fileSize, countStyle: .file)
        subtitleLabel.font = AppTheme.font(.footnote)
        subtitleLabel.textColor = AppTheme.secondaryTextColor
        subtitleLabel.isHidden = false
        valueLabel.isHidden = true
        chevronImageView.isHidden = false
        selectionStyle = .default
        accessibilityLabel = "\(document.displayName), \(subtitleLabel.text ?? "")"
        accessibilityHint = "Belge önizlemesini açar"
        accessibilityTraits = .button
    }
}
