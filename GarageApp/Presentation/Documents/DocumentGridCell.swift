//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

final class DocumentGridCell: UICollectionViewCell {
    static let reuseIdentifier = "DocumentGridCell"

    @IBOutlet private weak var thumbnailImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var badgeLabel: DocumentBadgeLabel!
    @IBOutlet private weak var metadataLabel: UILabel!
    @IBOutlet private weak var menuButton: UIButton!

    private(set) var representedDocumentID: UUID?

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.clipsToBounds = true
        AppTheme.styleBorderedSurface(
            contentView,
            backgroundColor: AppTheme.surfaceColor,
            cornerRadius: AppTheme.Radius.control
        )

        thumbnailImageView.backgroundColor = AppTheme.inputColor
        thumbnailImageView.tintColor = AppTheme.secondaryTextColor.withAlphaComponent(0.55)
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 5
        thumbnailImageView.layer.cornerCurve = .continuous

        titleLabel.font = AppTheme.font(.subheadline, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82

        badgeLabel.font = AppTheme.font(.caption2, weight: .medium)
        badgeLabel.textColor = AppTheme.accentColor
        badgeLabel.backgroundColor = AppTheme.accentSoftColor
        badgeLabel.layer.cornerRadius = 7
        badgeLabel.layer.cornerCurve = .continuous
        badgeLabel.clipsToBounds = true

        metadataLabel.font = AppTheme.font(.caption1)
        metadataLabel.textColor = AppTheme.secondaryTextColor
        metadataLabel.adjustsFontForContentSizeCategory = true

        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "ellipsis")
        configuration.baseForegroundColor = AppTheme.secondaryTextColor
        configuration.contentInsets = .zero
        menuButton.configuration = configuration
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.accessibilityLabel = "Belge işlemleri"
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedDocumentID = nil
        thumbnailImageView.image = nil
        menuButton.menu = nil
    }

    func configure(
        document: GarageDocument,
        title: String,
        badgeText: String?,
        metadataText: String,
        thumbnail: UIImage?,
        onOpen: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        representedDocumentID = document.id
        titleLabel.text = title
        badgeLabel.text = badgeText
        badgeLabel.isHidden = badgeText == nil
        metadataLabel.text = metadataText
        applyThumbnail(thumbnail, isPhoto: document.mimeType.hasPrefix("image/"))

        menuButton.menu = UIMenu(children: [
            UIAction(title: "Önizle", image: UIImage(systemName: "eye")) { _ in onOpen() },
            UIAction(title: "Sil", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in onDelete() }
        ])

        accessibilityLabel = [title, badgeText, metadataText].compactMap { $0 }.joined(separator: ", ")
        accessibilityHint = "Belge önizlemesini açar"
    }

    func setThumbnail(_ image: UIImage, for documentID: UUID, isPhoto: Bool) {
        guard representedDocumentID == documentID else { return }
        applyThumbnail(image, isPhoto: isPhoto)
    }

    private func applyThumbnail(_ image: UIImage?, isPhoto: Bool) {
        if let image {
            thumbnailImageView.image = image
            thumbnailImageView.contentMode = isPhoto ? .scaleAspectFill : .scaleAspectFit
            thumbnailImageView.tintColor = nil
        } else {
            thumbnailImageView.image = UIImage(systemName: "doc.text.image")
            thumbnailImageView.contentMode = .center
            thumbnailImageView.tintColor = AppTheme.secondaryTextColor.withAlphaComponent(0.55)
        }
    }
}

final class DocumentBadgeLabel: UILabel {
    private let contentInsets = UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
