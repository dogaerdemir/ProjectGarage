//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

final class VehicleListContentView: UIView {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIButton!

    static func instantiate() -> VehicleListContentView {
        guard let view = UINib(nibName: "VehicleListContentView", bundle: .main)
            .instantiate(withOwner: nil)
            .first as? VehicleListContentView else {
            preconditionFailure("VehicleListContentView.xib could not be loaded")
        }
        view.backgroundColor = AppTheme.backgroundColor
        view.tableView.backgroundColor = AppTheme.backgroundColor
        view.addButton.superview?.backgroundColor = AppTheme.backgroundColor
        return view
    }
}

final class VehicleCardCell: UITableViewCell {
    static let reuseIdentifier = "VehicleCardCell"

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var nicknameContainerView: UIView!
    @IBOutlet private weak var nicknameLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var plateIconImageView: UIImageView!
    @IBOutlet private weak var plateLabel: UILabel!
    @IBOutlet private weak var mileageIconImageView: UIImageView!
    @IBOutlet private weak var mileageLabel: UILabel!
    @IBOutlet private weak var vehicleImageView: UIImageView!
    @IBOutlet private weak var selectedContainerView: UIView!
    @IBOutlet private weak var selectedImageView: UIImageView!

    private var isCurrentVehicle = false

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
        selectionStyle = .none

        cardView.backgroundColor = AppTheme.surfaceColor
        cardView.layer.cornerRadius = AppTheme.Radius.control
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.025
        cardView.layer.shadowRadius = 7
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)

        nicknameContainerView.backgroundColor = AppTheme.accentSoftColor
        nicknameContainerView.layer.cornerRadius = 11
        nicknameContainerView.layer.cornerCurve = .continuous
        nicknameLabel.font = AppTheme.font(.caption1, weight: .semibold)
        nicknameLabel.textColor = AppTheme.accentColor

        titleLabel.font = AppTheme.font(.headline, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true

        [plateLabel, mileageLabel].forEach {
            $0?.font = AppTheme.font(.subheadline)
            $0?.textColor = AppTheme.primaryTextColor
            $0?.adjustsFontForContentSizeCategory = true
        }
        plateIconImageView.image = UIImage(systemName: "licenseplate")
        mileageIconImageView.image = UIImage(systemName: "gauge.with.dots.needle.50percent")
        [plateIconImageView, mileageIconImageView].forEach { $0?.tintColor = AppTheme.secondaryTextColor }

        vehicleImageView.contentMode = .scaleAspectFit
        vehicleImageView.image = UIImage(named: "VehiclePlaceholder")

        selectedContainerView.backgroundColor = AppTheme.accentColor
        selectedContainerView.layer.cornerRadius = 12
        selectedContainerView.layer.cornerCurve = .continuous
        selectedImageView.image = UIImage(systemName: "checkmark")
        selectedImageView.tintColor = AppTheme.onAccentColor

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: VehicleCardCell, _) in
            cell.updateSelectionAppearance()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        vehicleImageView.image = UIImage(named: "VehiclePlaceholder")
        contentView.alpha = 1
        isCurrentVehicle = false
        updateSelectionAppearance()
    }

    func configure(vehicle: Vehicle, isSelected: Bool, image: UIImage?) {
        nicknameLabel.text = vehicle.isArchived ? "\(vehicle.nickname) · Arşiv" : vehicle.nickname
        titleLabel.text = vehicleTitle(vehicle)
        plateLabel.text = normalized(vehicle.plateNumber) ?? "Plaka eklenmedi"
        let mileage = AppFormatters.mileage.string(from: NSNumber(value: vehicle.currentMileage)) ?? String(vehicle.currentMileage)
        mileageLabel.text = "\(mileage) km"
        vehicleImageView.image = image ?? UIImage(named: "VehiclePlaceholder")
        contentView.alpha = vehicle.isArchived ? 0.56 : 1
        isCurrentVehicle = isSelected && !vehicle.isArchived
        updateSelectionAppearance()

        accessibilityLabel = [
            vehicle.nickname,
            vehicleTitle(vehicle),
            normalized(vehicle.plateNumber),
            "\(mileage) kilometre",
            vehicle.isArchived ? "Arşivlendi" : (isSelected ? "Seçili araç" : nil)
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
        accessibilityHint = vehicle.isArchived ? "Düzenlemek için işlem menüsünü kullanın" : "Bu aracı seçer"
        accessibilityTraits = isCurrentVehicle ? [.button, .selected] : .button
    }

    private func vehicleTitle(_ vehicle: Vehicle) -> String {
        let makeAndModel = [vehicle.make, vehicle.model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        var parts = makeAndModel.isEmpty ? [vehicle.nickname] : [makeAndModel]
        if let year = vehicle.modelYear { parts.append(String(year)) }
        return parts.joined(separator: " • ")
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private func updateSelectionAppearance() {
        selectedContainerView.isHidden = !isCurrentVehicle
        cardView.layer.borderWidth = isCurrentVehicle ? 2 : AppTheme.Metrics.borderWidth
        let color = isCurrentVehicle ? AppTheme.accentColor : AppTheme.borderColor
        cardView.layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
    }
}

final class VehicleEditorFieldCell: UITableViewCell {
    static let reuseIdentifier = "VehicleEditorFieldCell"

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var valueLabel: UILabel!
    @IBOutlet private weak var chevronImageView: UIImageView!

    private var onValueChanged: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        var background = UIBackgroundConfiguration.listCell()
        background.backgroundColor = AppTheme.surfaceColor
        backgroundConfiguration = background
        contentView.backgroundColor = .clear

        titleLabel.font = AppTheme.font(.body)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true

        textField.font = AppTheme.font(.subheadline)
        textField.textColor = AppTheme.primaryTextColor
        textField.adjustsFontForContentSizeCategory = true
        textField.clearButtonMode = .whileEditing
        textField.addTarget(self, action: #selector(valueChanged), for: .editingChanged)

        valueLabel.font = AppTheme.font(.subheadline)
        valueLabel.adjustsFontForContentSizeCategory = true
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = AppTheme.secondaryTextColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onValueChanged = nil
        textField.text = nil
        textField.inputAccessoryView = nil
        valueLabel.text = nil
    }

    func configureText(
        title: String,
        value: String,
        placeholder: String,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        onValueChanged: @escaping (String) -> Void
    ) {
        titleLabel.text = title
        textField.isHidden = false
        valueLabel.isHidden = true
        chevronImageView.isHidden = true
        selectionStyle = .none
        textField.text = value
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: AppTheme.secondaryTextColor.withAlphaComponent(0.78)]
        )
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.inputAccessoryView = keyboardAccessory(for: keyboardType)
        textField.accessibilityLabel = title
        accessibilityTraits = []
        self.onValueChanged = onValueChanged
    }

    func configureSelection(title: String, value: String?, placeholder: String = "Seçiniz") {
        onValueChanged = nil
        titleLabel.text = title
        textField.isHidden = true
        valueLabel.isHidden = false
        chevronImageView.isHidden = false
        selectionStyle = .default
        valueLabel.text = value ?? placeholder
        valueLabel.textColor = value == nil ? AppTheme.secondaryTextColor : AppTheme.primaryTextColor
        accessibilityLabel = title
        accessibilityValue = value ?? "Seçilmedi"
        accessibilityHint = "Seçenekleri açar"
        accessibilityTraits = .button
    }

    private func keyboardAccessory(for keyboardType: UIKeyboardType) -> UIView? {
        guard keyboardType == .numberPad || keyboardType == .decimalPad else { return nil }
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Bitti", style: .done, target: self, action: #selector(doneTapped))
        ]
        return toolbar
    }

    @objc private func valueChanged() { onValueChanged?(textField.text ?? "") }
    @objc private func doneTapped() { textField.resignFirstResponder() }
}

final class VehicleEditorPhotoCell: UITableViewCell {
    static let reuseIdentifier = "VehicleEditorPhotoCell"

    @IBOutlet private weak var photoContainerView: UIView!
    @IBOutlet private weak var previewImageView: UIImageView!
    @IBOutlet private weak var emptyContentStackView: UIStackView!
    @IBOutlet private weak var cameraContainerView: UIView!
    @IBOutlet private weak var cameraImageView: UIImageView!
    @IBOutlet private weak var promptLabel: UILabel!
    @IBOutlet private weak var changeContainerView: UIView!
    @IBOutlet private weak var changeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        photoContainerView.backgroundColor = AppTheme.inputColor
        photoContainerView.layer.cornerRadius = AppTheme.Radius.control
        photoContainerView.layer.cornerCurve = .continuous
        photoContainerView.layer.borderWidth = AppTheme.Metrics.borderWidth
        updateBorderColor()

        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        previewImageView.layer.cornerRadius = AppTheme.Radius.control
        previewImageView.layer.cornerCurve = .continuous

        cameraContainerView.backgroundColor = AppTheme.surfaceColor
        cameraContainerView.layer.cornerRadius = 26
        cameraContainerView.layer.cornerCurve = .continuous
        cameraContainerView.layer.borderWidth = AppTheme.Metrics.borderWidth
        cameraContainerView.layer.borderColor = AppTheme.borderColor.cgColor
        cameraImageView.image = UIImage(systemName: "camera")
        cameraImageView.tintColor = AppTheme.secondaryTextColor

        promptLabel.text = "Araç Fotoğrafı Ekle"
        promptLabel.font = AppTheme.font(.subheadline, weight: .medium)
        promptLabel.textColor = AppTheme.secondaryTextColor
        promptLabel.adjustsFontForContentSizeCategory = true

        changeContainerView.backgroundColor = AppTheme.surfaceColor.withAlphaComponent(0.92)
        changeContainerView.layer.cornerRadius = 12
        changeContainerView.layer.cornerCurve = .continuous
        changeLabel.text = "Fotoğrafı Değiştir"
        changeLabel.font = AppTheme.font(.caption1, weight: .semibold)
        changeLabel.textColor = AppTheme.accentColor

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: VehicleEditorPhotoCell, _) in
            cell.updateBorderColor()
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Fotoğraf arşivini açar"
    }

    func configure(image: UIImage?) {
        previewImageView.image = image
        previewImageView.isHidden = image == nil
        emptyContentStackView.isHidden = image != nil
        changeContainerView.isHidden = image == nil
        accessibilityLabel = image == nil ? "Araç fotoğrafı ekle" : "Araç fotoğrafını değiştir"
    }

    private func updateBorderColor() {
        photoContainerView.layer.borderColor = AppTheme.borderColor.resolvedColor(with: traitCollection).cgColor
    }
}
