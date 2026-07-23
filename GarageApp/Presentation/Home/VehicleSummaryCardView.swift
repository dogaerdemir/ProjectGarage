//
//  Created by Doğa Erdemir on 13.07.2026.
//

import UIKit

final class VehicleSummaryCardView: UIView {
    @IBOutlet private weak var vehicleNameLabel: UILabel!
    @IBOutlet private weak var yearContainerView: UIView!
    @IBOutlet private weak var yearLabel: UILabel!
    @IBOutlet private weak var plateTitleLabel: UILabel!
    @IBOutlet private weak var plateContainerView: UIView!
    @IBOutlet private weak var plateCountryLabel: UILabel!
    @IBOutlet private weak var plateValueLabel: UILabel!
    @IBOutlet private weak var plateCopyButton: UIButton!
    @IBOutlet private weak var vinTitleLabel: UILabel!
    @IBOutlet private weak var vinContainerView: UIView!
    @IBOutlet private weak var vinValueLabel: UILabel!
    @IBOutlet private weak var vinCopyButton: UIButton!
    @IBOutlet private weak var vehicleImageView: UIImageView!
    @IBOutlet private weak var dividerView: UIView!
    @IBOutlet private weak var mileageTitleLabel: UILabel!
    @IBOutlet private weak var mileageValueLabel: UILabel!
    @IBOutlet private weak var updateMileageButton: UIButton!

    private var plateCopyValue: String?
    private var vinCopyValue: String?
    private var onUpdateMileage: (() -> Void)?

    static func instantiate() -> VehicleSummaryCardView {
        guard let view = UINib(nibName: "VehicleSummaryCardView", bundle: .main)
            .instantiate(withOwner: nil)
            .first as? VehicleSummaryCardView else {
            preconditionFailure("VehicleSummaryCardView.xib could not be loaded")
        }
        return view
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        configureAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: VehicleSummaryCardView, _) in
            view.updateBorderColors()
        }
    }

    func configure(
        vehicle: Vehicle,
        imageData: Data?,
        onUpdateMileage: @escaping () -> Void
    ) {
        self.onUpdateMileage = onUpdateMileage

        vehicleNameLabel.text = vehicleName(vehicle)
        if let modelYear = vehicle.modelYear {
            yearLabel.text = String(modelYear)
            yearContainerView.isHidden = false
        } else {
            yearContainerView.isHidden = true
        }

        plateCopyValue = normalizedValue(vehicle.plateNumber)?
            .uppercased(with: Locale(identifier: "tr_TR"))
        plateValueLabel.text = plateCopyValue ?? "Eklenmedi"

        vinCopyValue = normalizedValue(vehicle.vin)?
            .uppercased(with: Locale(identifier: "tr_TR"))
        vinValueLabel.text = vinCopyValue ?? "Eklenmedi"

        let formattedMileage = AppFormatters.mileage.string(from: NSNumber(value: vehicle.currentMileage))
            ?? String(vehicle.currentMileage)
        mileageValueLabel.attributedText = mileageText(formattedMileage)

        if let image = imageData.flatMap(UIImage.init(data:)) {
            vehicleImageView.image = image
            vehicleImageView.tintColor = nil
            vehicleImageView.backgroundColor = AppTheme.inputColor
        } else {
            vehicleImageView.image = UIImage(
                systemName: "car.side.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 54, weight: .regular)
            )
            vehicleImageView.tintColor = AppTheme.accentColor
            vehicleImageView.backgroundColor = AppTheme.accentSoftColor
        }
        configureCopyButtonAvailability()

        plateContainerView.accessibilityLabel = "Plaka, \(plateValueLabel.text ?? "")"
        vinContainerView.accessibilityLabel = "Şasi numarası, \(vinValueLabel.text ?? "")"
        mileageValueLabel.accessibilityLabel = "Güncel kilometre, \(formattedMileage) kilometre"
    }

    private func configureAppearance() {
        AppTheme.styleCard(self)

        vehicleNameLabel.font = AppTheme.font(.title1, weight: .bold)
        vehicleNameLabel.textColor = AppTheme.primaryTextColor
        vehicleNameLabel.adjustsFontForContentSizeCategory = true
        vehicleNameLabel.adjustsFontSizeToFitWidth = true
        vehicleNameLabel.minimumScaleFactor = 0.75
        vehicleNameLabel.accessibilityTraits = .header

        yearContainerView.backgroundColor = AppTheme.inputColor
        yearContainerView.layer.cornerRadius = 7
        yearContainerView.layer.cornerCurve = .continuous
        yearContainerView.layer.borderWidth = AppTheme.Metrics.borderWidth
        yearContainerView.transform = CGAffineTransform(translationX: 0, y: 1)
        yearLabel.font = AppTheme.font(.subheadline, weight: .semibold)
        yearLabel.textColor = AppTheme.primaryTextColor
        yearLabel.adjustsFontForContentSizeCategory = true

        [plateTitleLabel, vinTitleLabel, mileageTitleLabel].forEach {
            $0?.font = AppTheme.font(.subheadline, weight: .regular)
            $0?.textColor = AppTheme.secondaryTextColor
            $0?.adjustsFontForContentSizeCategory = true
        }

        plateContainerView.backgroundColor = AppTheme.surfaceColor
        plateContainerView.layer.cornerRadius = 4
        plateContainerView.layer.cornerCurve = .continuous
        plateContainerView.layer.borderWidth = 1.5
        plateContainerView.clipsToBounds = true
        plateContainerView.isAccessibilityElement = true
        plateCountryLabel.backgroundColor = UIColor.systemBlue
        plateCountryLabel.textColor = .white
        plateCountryLabel.font = UIFontMetrics(forTextStyle: .caption2).scaledFont(
            for: UIFont.systemFont(ofSize: 9, weight: .bold)
        )
        plateValueLabel.font = scaledMonospacedFont(size: 14, weight: .bold, textStyle: .subheadline)
        plateValueLabel.textColor = AppTheme.primaryTextColor
        plateValueLabel.adjustsFontSizeToFitWidth = true
        plateValueLabel.minimumScaleFactor = 0.65

        vinContainerView.backgroundColor = AppTheme.inputColor
        vinContainerView.layer.cornerRadius = AppTheme.Radius.compact
        vinContainerView.layer.cornerCurve = .continuous
        vinContainerView.layer.borderWidth = AppTheme.Metrics.borderWidth
        vinContainerView.isAccessibilityElement = true
        vinValueLabel.font = scaledMonospacedFont(size: 12, weight: .medium, textStyle: .footnote)
        vinValueLabel.textColor = AppTheme.primaryTextColor
        vinValueLabel.adjustsFontSizeToFitWidth = true
        vinValueLabel.minimumScaleFactor = 0.65

        configureCopyButton(plateCopyButton, accessibilityLabel: "Plakayı kopyala")
        configureCopyButton(vinCopyButton, accessibilityLabel: "Şasi numarasını kopyala")

        vehicleImageView.contentMode = .scaleAspectFit
        vehicleImageView.layer.cornerRadius = AppTheme.Radius.compact
        vehicleImageView.layer.cornerCurve = .continuous
        vehicleImageView.clipsToBounds = true
        vehicleImageView.accessibilityLabel = "Araç fotoğrafı"
        dividerView.backgroundColor = AppTheme.borderColor

        var mileageConfiguration = AppTheme.primaryButtonConfiguration(title: "Kilometre Güncelle")
        mileageConfiguration.image = nil
        mileageConfiguration.imagePadding = 0
        mileageConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        updateMileageButton.configuration = mileageConfiguration
        updateMileageButton.accessibilityHint = "Kilometre güncelleme formunu açar"
        updateMileageButton.titleLabel?.adjustsFontForContentSizeCategory = true
        updateMileageButton.titleLabel?.numberOfLines = 1
        updateMileageButton.titleLabel?.adjustsFontSizeToFitWidth = true
        updateMileageButton.titleLabel?.minimumScaleFactor = 0.8

        updateBorderColors()
    }

    private func configureCopyButton(_ button: UIButton, accessibilityLabel: String) {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "doc.on.doc")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        configuration.baseForegroundColor = AppTheme.accentColor
        configuration.baseBackgroundColor = AppTheme.accentSoftColor
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .zero
        button.configuration = configuration
        button.accessibilityLabel = accessibilityLabel
    }

    private func configureCopyButtonAvailability() {
        plateCopyButton.isEnabled = plateCopyValue != nil
        plateCopyButton.alpha = plateCopyButton.isEnabled ? 1 : 0.4
        vinCopyButton.isEnabled = vinCopyValue != nil
        vinCopyButton.alpha = vinCopyButton.isEnabled ? 1 : 0.4
    }

    private func copy(_ value: String?, using button: UIButton, announcement: String) {
        guard let value else { return }
        UIPasteboard.general.string = value
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: announcement)

        var configuration = button.configuration
        configuration?.image = UIImage(systemName: "checkmark")
        button.configuration = configuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak button] in
            guard let button else { return }
            var configuration = button.configuration
            configuration?.image = UIImage(systemName: "doc.on.doc")
            button.configuration = configuration
        }
    }

    private func vehicleName(_ vehicle: Vehicle) -> String {
        let parts = [vehicle.make, vehicle.model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? vehicle.nickname : parts.joined(separator: " ")
    }

    private func normalizedValue(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private func mileageText(_ mileage: String) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: mileage,
            attributes: [
                .font: AppTheme.font(.title1, weight: .bold),
                .foregroundColor: AppTheme.accentColor
            ]
        )
        text.append(NSAttributedString(
            string: " km",
            attributes: [
                .font: AppTheme.font(.body, weight: .semibold),
                .foregroundColor: AppTheme.accentColor
            ]
        ))
        return text
    }

    private func scaledMonospacedFont(
        size: CGFloat,
        weight: UIFont.Weight,
        textStyle: UIFont.TextStyle
    ) -> UIFont {
        UIFontMetrics(forTextStyle: textStyle).scaledFont(
            for: UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        )
    }

    private func updateBorderColors() {
        let borderColor = AppTheme.borderColor.resolvedColor(with: traitCollection).cgColor
        yearContainerView.layer.borderColor = borderColor
        vinContainerView.layer.borderColor = borderColor
        plateContainerView.layer.borderColor = borderColor
        dividerView.backgroundColor = AppTheme.borderColor.resolvedColor(with: traitCollection)
    }

    @IBAction private func plateCopyTapped() {
        copy(plateCopyValue, using: plateCopyButton, announcement: "Plaka kopyalandı")
    }

    @IBAction private func vinCopyTapped() {
        copy(vinCopyValue, using: vinCopyButton, announcement: "Şasi numarası kopyalandı")
    }

    @IBAction private func updateMileageTapped() {
        onUpdateMileage?()
    }
}
