//
//  Created by Doğa Erdemir on 24.07.2026.
//

import MapKit
import UIKit

final class NearbyPlaceCell: UITableViewCell {
    static let reuseIdentifier = "NearbyPlaceCell"

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var metadataLabel: UILabel!
    @IBOutlet private weak var chevronImageView: UIImageView!

    private let distanceFormatter: MKDistanceFormatter = {
        let formatter = MKDistanceFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitStyle = .abbreviated
        return formatter
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        isAccessibilityElement = true

        AppTheme.styleCard(cardView)
        iconContainerView.layer.cornerRadius = 22
        iconContainerView.layer.cornerCurve = .continuous
        iconImageView.contentMode = .scaleAspectFit

        titleLabel.font = AppTheme.font(.body, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        addressLabel.font = AppTheme.font(.subheadline)
        addressLabel.textColor = AppTheme.secondaryTextColor
        addressLabel.adjustsFontForContentSizeCategory = true
        metadataLabel.font = AppTheme.font(.footnote, weight: .medium)
        metadataLabel.textColor = AppTheme.secondaryTextColor
        metadataLabel.adjustsFontForContentSizeCategory = true
        chevronImageView.tintColor = AppTheme.secondaryTextColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        addressLabel.text = nil
        addressLabel.isHidden = false
        metadataLabel.text = nil
        iconImageView.image = nil
        cardView.transform = .identity
        cardView.alpha = 1
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let changes = {
            self.cardView.transform = highlighted
                ? CGAffineTransform(scaleX: 0.985, y: 0.985)
                : .identity
            self.cardView.alpha = highlighted ? 0.78 : 1
        }
        animated ? UIView.animate(withDuration: 0.16, animations: changes) : changes()
    }

    func configure(with place: NearbyPlace) {
        let tint = place.category.displayColor
        iconContainerView.backgroundColor = tint.withAlphaComponent(0.13)
        iconImageView.tintColor = tint
        iconImageView.image = UIImage(systemName: place.category.symbolName)
        titleLabel.text = place.name
        addressLabel.text = place.address
        addressLabel.isHidden = place.address == nil

        var metadata = [distanceFormatter.string(fromDistance: place.distance)]
        if place.phoneNumber?.isEmpty == false { metadata.append("Telefon var") }
        metadataLabel.text = metadata.joined(separator: "  •  ")

        accessibilityLabel = [
            place.name,
            place.category.title,
            place.address,
            metadata.joined(separator: ", ")
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
        accessibilityHint = "İşletme ayrıntılarını açar"
        accessibilityTraits = .button
    }
}
extension NearbyCategory {
    var displayColor: UIColor {
        switch self {
        case .fuel: .systemOrange
        case .service: AppTheme.accentColor
        case .tire: .systemIndigo
        case .carWash: .systemCyan
        case .inspection: AppTheme.successColor
        }
    }
}
