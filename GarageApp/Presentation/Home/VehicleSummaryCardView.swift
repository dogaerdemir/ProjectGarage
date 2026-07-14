//
//  Created by Doğa Erdemir on 13.07.2026.
//

import UIKit

final class VehicleSummaryCardView: UIView {
    @IBOutlet private weak var vehicleIconContainerView: UIView!
    @IBOutlet private weak var vehicleIconImageView: UIImageView!
    @IBOutlet private weak var vehicleNameLabel: UILabel!
    @IBOutlet private weak var vehicleDescriptionLabel: UILabel!
    @IBOutlet private weak var plateContainerView: UIView!
    @IBOutlet private weak var plateTitleLabel: UILabel!
    @IBOutlet private weak var plateValueLabel: UILabel!
    @IBOutlet private weak var mileageContainerView: UIView!
    @IBOutlet private weak var mileageTitleLabel: UILabel!
    @IBOutlet private weak var mileageValueLabel: UILabel!
    @IBOutlet private weak var mileageIconImageView: UIImageView!
    @IBOutlet private weak var vinContainerView: UIView!
    @IBOutlet private weak var vinTitleLabel: UILabel!
    @IBOutlet private weak var vinValueLabel: UILabel!
    @IBOutlet private weak var dividerView: UIView!
    @IBOutlet private weak var actionsStackView: UIStackView!
    @IBOutlet private weak var chooseVehicleButton: UIButton!
    @IBOutlet private weak var updateMileageButton: UIButton!

    private var onChooseVehicle: (() -> Void)?
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
        updateActionsLayout()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: VehicleSummaryCardView, _) in
            view.updateActionsLayout()
        }
    }

    func configure(
        vehicle: Vehicle,
        onChooseVehicle: @escaping () -> Void,
        onUpdateMileage: @escaping () -> Void
    ) {
        self.onChooseVehicle = onChooseVehicle
        self.onUpdateMileage = onUpdateMileage

        vehicleNameLabel.text = vehicle.nickname
        let description = vehicleDescription(vehicle)
        vehicleDescriptionLabel.text = description
        vehicleDescriptionLabel.isHidden = description == nil

        if let plate = normalizedValue(vehicle.plateNumber) {
            plateContainerView.isHidden = false
            plateValueLabel.text = plate.uppercased(with: Locale(identifier: "tr_TR"))
            plateContainerView.accessibilityLabel = "Plaka, \(plate)"
        } else {
            plateContainerView.isHidden = true
        }

        let formattedMileage = AppFormatters.mileage.string(from: NSNumber(value: vehicle.currentMileage)) ?? String(vehicle.currentMileage)
        mileageValueLabel.text = "\(formattedMileage) km"
        mileageContainerView.accessibilityLabel = "Güncel kilometre, \(formattedMileage) kilometre"

        if let vin = normalizedValue(vehicle.vin) {
            vinContainerView.isHidden = false
            vinValueLabel.text = vin.uppercased()
            vinContainerView.accessibilityLabel = "Şasi numarası, \(vin)"
        } else {
            vinContainerView.isHidden = true
        }
    }

    private func configureAppearance() {
        AppTheme.styleCard(self)
        AppTheme.styleBorderedSurface(
            vehicleIconContainerView,
            backgroundColor: AppTheme.accentSoftColor,
            cornerRadius: AppTheme.Radius.card
        )
        AppTheme.styleBorderedSurface(plateContainerView, backgroundColor: AppTheme.inputColor)
        AppTheme.styleBorderedSurface(mileageContainerView, backgroundColor: AppTheme.inputColor)
        AppTheme.styleBorderedSurface(vinContainerView, backgroundColor: AppTheme.inputColor)

        vehicleIconImageView.tintColor = AppTheme.accentColor
        mileageIconImageView.tintColor = AppTheme.accentColor
        dividerView.backgroundColor = AppTheme.borderColor

        vehicleNameLabel.font = AppTheme.font(.title2, weight: .bold)
        vehicleNameLabel.textColor = AppTheme.primaryTextColor
        vehicleNameLabel.accessibilityTraits = .header
        vehicleDescriptionLabel.font = AppTheme.font(.subheadline)
        vehicleDescriptionLabel.textColor = AppTheme.secondaryTextColor

        [plateTitleLabel, mileageTitleLabel, vinTitleLabel].forEach {
            $0?.font = AppTheme.font(.caption1, weight: .semibold)
            $0?.textColor = AppTheme.secondaryTextColor
        }
        plateValueLabel.font = scaledMonospacedFont(size: 15, weight: .semibold, textStyle: .subheadline)
        plateValueLabel.textColor = AppTheme.primaryTextColor
        mileageValueLabel.font = AppTheme.font(.title1, weight: .bold)
        mileageValueLabel.textColor = AppTheme.primaryTextColor
        vinValueLabel.font = scaledMonospacedFont(size: 14, weight: .medium, textStyle: .subheadline)
        vinValueLabel.textColor = AppTheme.primaryTextColor

        var chooseConfiguration = AppTheme.secondaryButtonConfiguration(title: "Araç Değiştir", symbol: "car.2.fill")
        chooseConfiguration.titleLineBreakMode = .byWordWrapping
        chooseVehicleButton.configuration = chooseConfiguration
        chooseVehicleButton.accessibilityHint = "Araç listesini açar"

        var mileageConfiguration = AppTheme.primaryButtonConfiguration(title: "Kilometre Güncelle", symbol: "gauge.with.dots.needle.50percent")
        mileageConfiguration.titleLineBreakMode = .byWordWrapping
        updateMileageButton.configuration = mileageConfiguration
        updateMileageButton.accessibilityHint = "Kilometre güncelleme formunu açar"

        [chooseVehicleButton, updateMileageButton].forEach {
            $0?.titleLabel?.adjustsFontForContentSizeCategory = true
            $0?.titleLabel?.numberOfLines = 0
            $0?.titleLabel?.textAlignment = .center
        }

        plateContainerView.isAccessibilityElement = true
        mileageContainerView.isAccessibilityElement = true
        vinContainerView.isAccessibilityElement = true
    }

    private func updateActionsLayout() {
        let usesVerticalLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        actionsStackView.axis = usesVerticalLayout ? .vertical : .horizontal
        actionsStackView.distribution = usesVerticalLayout ? .fill : .fillEqually
    }

    private func vehicleDescription(_ vehicle: Vehicle) -> String? {
        let makeAndModel = [vehicle.make, vehicle.model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        var parts: [String] = makeAndModel.isEmpty ? [] : [makeAndModel]
        if let year = vehicle.modelYear { parts.append(String(year)) }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func normalizedValue(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private func scaledMonospacedFont(size: CGFloat, weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> UIFont {
        UIFontMetrics(forTextStyle: textStyle).scaledFont(
            for: UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        )
    }

    @IBAction private func chooseVehicleTapped() { onChooseVehicle?() }
    @IBAction private func updateMileageTapped() { onUpdateMileage?() }
}
