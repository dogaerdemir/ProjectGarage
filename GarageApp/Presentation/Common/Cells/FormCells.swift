//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

class BaseFormCell: UITableViewCell {
    @IBOutlet weak var fieldTitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = AppTheme.surfaceColor
        contentView.backgroundColor = AppTheme.surfaceColor
        fieldTitleLabel.font = AppTheme.font(.subheadline, weight: .semibold)
        fieldTitleLabel.adjustsFontForContentSizeCategory = true
        fieldTitleLabel.textColor = AppTheme.primaryTextColor
        fieldTitleLabel.numberOfLines = 0
    }

    func styleControlSurface(_ view: UIView) {
        view.backgroundColor = AppTheme.inputColor
        view.layer.cornerRadius = AppTheme.Radius.control
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = AppTheme.Metrics.borderWidth
        view.layer.borderColor = AppTheme.borderColor.resolvedColor(with: traitCollection).cgColor
    }
}

final class AppTextField: UITextField {
    private let contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

    override func awakeFromNib() {
        super.awakeFromNib()
        borderStyle = .none
        font = AppTheme.font(.body)
        adjustsFontForContentSizeCategory = true
        textColor = AppTheme.primaryTextColor
        backgroundColor = AppTheme.inputColor
        layer.cornerRadius = AppTheme.Radius.control
        layer.cornerCurve = .continuous
        layer.borderWidth = AppTheme.Metrics.borderWidth
        layer.borderColor = AppTheme.borderColor.resolvedColor(with: traitCollection).cgColor
        addTarget(self, action: #selector(beginEditing), for: .editingDidBegin)
        addTarget(self, action: #selector(editingEnded), for: .editingDidEnd)
    }

    func setPlaceholder(_ text: String) {
        attributedPlaceholder = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: AppTheme.secondaryTextColor.withAlphaComponent(0.78)]
        )
    }

    func updateKeyboardAccessory() {
        guard keyboardType == .numberPad || keyboardType == .decimalPad else {
            inputAccessoryView = nil
            return
        }
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Bitti", style: .done, target: self, action: #selector(doneTapped))
        ]
        inputAccessoryView = toolbar
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect { super.textRect(forBounds: bounds).inset(by: contentInsets) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { super.editingRect(forBounds: bounds).inset(by: contentInsets) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { super.placeholderRect(forBounds: bounds).inset(by: contentInsets) }

    @objc private func beginEditing() {
        layer.borderWidth = 1.5
        layer.borderColor = AppTheme.accentColor.resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = AppTheme.accentColor.resolvedColor(with: traitCollection).cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 5
        layer.shadowOffset = .zero
    }

    @objc private func editingEnded() {
        layer.borderWidth = AppTheme.Metrics.borderWidth
        layer.borderColor = AppTheme.borderColor.resolvedColor(with: traitCollection).cgColor
        layer.shadowOpacity = 0
    }

    @objc private func doneTapped() { resignFirstResponder() }
}

final class TextInputCell: BaseFormCell {
    @IBOutlet weak var textField: AppTextField!
    private var onValueChanged: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        textField.addTarget(self, action: #selector(valueChanged), for: .editingChanged)
    }

    func configure(
        title: String,
        value: String,
        placeholder: String,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        textContentType: UITextContentType? = nil,
        onValueChanged: @escaping (String) -> Void
    ) {
        fieldTitleLabel.text = title
        textField.text = value
        textField.setPlaceholder(placeholder)
        textField.keyboardType = keyboardType
        textField.updateKeyboardAccessory()
        textField.autocapitalizationType = autocapitalizationType
        textField.textContentType = textContentType
        textField.accessibilityLabel = title
        self.onValueChanged = onValueChanged
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onValueChanged = nil
        textField.text = nil
        textField.rightView = nil
        textField.textContentType = nil
    }

    @objc private func valueChanged() { onValueChanged?(textField.text ?? "") }
}

final class DecimalInputCell: BaseFormCell {
    @IBOutlet weak var textField: AppTextField!
    private var onValueChanged: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        textField.keyboardType = .decimalPad
        textField.addTarget(self, action: #selector(valueChanged), for: .editingChanged)
    }

    func configure(
        title: String,
        value: String,
        placeholder: String,
        keyboardType: UIKeyboardType = .decimalPad,
        suffix: String? = nil,
        onValueChanged: @escaping (String) -> Void
    ) {
        fieldTitleLabel.text = title
        textField.text = value
        textField.setPlaceholder(placeholder)
        textField.keyboardType = keyboardType
        textField.updateKeyboardAccessory()
        textField.accessibilityLabel = title
        textField.rightView = suffix.map(makeSuffixLabel)
        textField.rightViewMode = suffix == nil ? .never : .always
        self.onValueChanged = onValueChanged
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onValueChanged = nil
        textField.text = nil
        textField.rightView = nil
        textField.rightViewMode = .never
    }

    private func makeSuffixLabel(_ suffix: String) -> UIView {
        let label = UILabel()
        label.text = "  \(suffix)  "
        label.font = AppTheme.font(.subheadline, weight: .medium)
        label.textColor = AppTheme.secondaryTextColor
        label.sizeToFit()
        return label
    }

    @objc private func valueChanged() { onValueChanged?(textField.text ?? "") }
}

final class DatePickerCell: BaseFormCell {
    @IBOutlet weak var fieldContainer: UIView!
    @IBOutlet weak var datePicker: UIDatePicker!
    private var onValueChanged: ((Date) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        styleControlSurface(fieldContainer)
        datePicker.preferredDatePickerStyle = .compact
        datePicker.tintColor = AppTheme.accentColor
        datePicker.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
    }

    func configure(title: String, date: Date, onValueChanged: @escaping (Date) -> Void) {
        fieldTitleLabel.text = title
        datePicker.date = date
        datePicker.accessibilityLabel = title
        self.onValueChanged = onValueChanged
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onValueChanged = nil
    }

    @objc private func valueChanged() { onValueChanged?(datePicker.date) }
}

final class SelectionCell: BaseFormCell {
    @IBOutlet weak var fieldContainer: UIView!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var chevronImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .default
        styleControlSurface(fieldContainer)
        valueLabel.font = AppTheme.font(.body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0
        chevronImageView.image = UIImage(systemName: "chevron.down")
        chevronImageView.tintColor = AppTheme.secondaryTextColor
    }

    func configure(title: String, value: String?, placeholder: String = "Seçin") {
        fieldTitleLabel.text = title
        valueLabel.text = value ?? placeholder
        valueLabel.textColor = value == nil ? AppTheme.secondaryTextColor : AppTheme.primaryTextColor
        accessibilityLabel = title
        accessibilityValue = value ?? "Seçilmedi"
        accessibilityHint = "Seçenekleri açar"
        accessibilityTraits = .button
    }
}

final class ToggleCell: BaseFormCell {
    @IBOutlet weak var toggle: UISwitch!
    private var onValueChanged: ((Bool) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        fieldTitleLabel.font = AppTheme.font(.body, weight: .medium)
        toggle.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
    }

    func configure(title: String, isOn: Bool, onValueChanged: @escaping (Bool) -> Void) {
        fieldTitleLabel.text = title
        toggle.isOn = isOn
        toggle.accessibilityLabel = title
        self.onValueChanged = onValueChanged
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onValueChanged = nil
    }

    @objc private func valueChanged() { onValueChanged?(toggle.isOn) }
}

final class MultilineTextCell: BaseFormCell, UITextViewDelegate {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var placeholderLabel: UILabel!
    private var onValueChanged: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        textView.delegate = self
        textView.font = AppTheme.font(.body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = AppTheme.primaryTextColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        styleControlSurface(textView)
        placeholderLabel.font = AppTheme.font(.body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = AppTheme.secondaryTextColor.withAlphaComponent(0.78)
    }

    func configure(title: String, text: String, placeholder: String, onValueChanged: @escaping (String) -> Void) {
        fieldTitleLabel.text = title
        textView.text = text
        textView.accessibilityLabel = title
        placeholderLabel.text = placeholder
        placeholderLabel.isHidden = !text.isEmpty
        self.onValueChanged = onValueChanged
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onValueChanged = nil
        textView.text = nil
        placeholderLabel.isHidden = false
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        textView.layer.borderWidth = 1.5
        textView.layer.borderColor = AppTheme.accentColor.resolvedColor(with: traitCollection).cgColor
        textView.layer.shadowColor = AppTheme.accentColor.resolvedColor(with: traitCollection).cgColor
        textView.layer.shadowOpacity = 0.12
        textView.layer.shadowRadius = 5
        textView.layer.shadowOffset = .zero
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        textView.layer.borderWidth = AppTheme.Metrics.borderWidth
        textView.layer.borderColor = AppTheme.borderColor.resolvedColor(with: traitCollection).cgColor
        textView.layer.shadowOpacity = 0
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        onValueChanged?(textView.text)
    }
}

final class AttachmentPickerCell: BaseFormCell {
    @IBOutlet weak var actionButton: UIButton!
    private var onTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        actionButton.addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    func configure(title: String, actionTitle: String, symbol: String = "paperclip", onTap: @escaping () -> Void) {
        fieldTitleLabel.text = title
        actionButton.configuration = AppTheme.secondaryButtonConfiguration(title: actionTitle, symbol: symbol)
        actionButton.accessibilityLabel = actionTitle
        self.onTap = onTap
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
    }

    @objc private func tapped() { onTap?() }
}

final class DataListCell: UITableViewCell {
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var metadataStackView: UIStackView!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.surfaceColor
        contentView.backgroundColor = AppTheme.surfaceColor

        AppTheme.styleBorderedSurface(
            iconContainerView,
            backgroundColor: AppTheme.accentSoftColor,
            cornerRadius: AppTheme.Radius.compact
        )
        iconImageView.tintColor = AppTheme.accentColor

        titleLabel.font = AppTheme.font(.body, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2

        subtitleLabel.font = AppTheme.font(.subheadline)
        subtitleLabel.textColor = AppTheme.secondaryTextColor
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 2

        metadataStackView.spacing = AppTheme.Spacing.xSmall

        let selectedView = UIView()
        selectedView.backgroundColor = AppTheme.accentSoftColor
        selectedBackgroundView = selectedView
    }

    func configure(
        title: String,
        subtitle: String? = nil,
        metadata: [String] = [],
        symbol: String? = nil,
        tintColor: UIColor = AppTheme.accentColor,
        showsDisclosure: Bool = true
    ) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle?.isEmpty != false
        iconContainerView.isHidden = symbol == nil
        iconImageView.image = symbol.flatMap(UIImage.init(systemName:))
        iconImageView.tintColor = tintColor
        iconContainerView.backgroundColor = tintColor.withAlphaComponent(0.11)

        metadataStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        metadata.filter { !$0.isEmpty }.forEach { metadataStackView.addArrangedSubview(metadataRow($0, tintColor: tintColor)) }
        metadataStackView.isHidden = metadataStackView.arrangedSubviews.isEmpty

        accessoryType = showsDisclosure ? .disclosureIndicator : .none
        selectionStyle = showsDisclosure ? .default : .none
        accessibilityLabel = ([title, subtitle].compactMap { $0 } + metadata).joined(separator: ", ")
        accessibilityHint = showsDisclosure ? "Detayı açar" : nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        iconImageView.image = nil
        metadataStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        accessoryType = .none
        contentView.alpha = 1
        accessibilityHint = nil
    }

    private func metadataRow(_ text: String, tintColor: UIColor) -> UIView {
        let indicator = UIView()
        indicator.backgroundColor = tintColor.withAlphaComponent(0.72)
        indicator.layer.cornerRadius = 2
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 4),
            indicator.heightAnchor.constraint(equalToConstant: 4)
        ])

        let label = UILabel()
        label.text = text
        label.font = AppTheme.font(.footnote, weight: .medium)
        label.textColor = AppTheme.secondaryTextColor
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [indicator, label])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = AppTheme.Spacing.small
        return row
    }
}

final class KeyValueCell: UITableViewCell {
    @IBOutlet private weak var keyLabel: UILabel!
    @IBOutlet private weak var valueLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.surfaceColor
        keyLabel.font = AppTheme.font(.footnote, weight: .semibold)
        keyLabel.textColor = AppTheme.secondaryTextColor
        keyLabel.adjustsFontForContentSizeCategory = true
        valueLabel.font = AppTheme.font(.body, weight: .medium)
        valueLabel.textColor = AppTheme.primaryTextColor
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0
        selectionStyle = .none
    }

    func configure(key: String, value: String) {
        keyLabel.text = key
        valueLabel.text = value
        accessibilityLabel = "\(key), \(value)"
    }
}

final class DocumentListCell: UITableViewCell {
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var metadataLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.surfaceColor
        iconContainerView.backgroundColor = AppTheme.accentSoftColor
        iconContainerView.layer.cornerRadius = AppTheme.Radius.compact
        iconContainerView.layer.cornerCurve = .continuous
        iconImageView.tintColor = AppTheme.accentColor
        nameLabel.font = AppTheme.font(.body, weight: .semibold)
        nameLabel.textColor = AppTheme.primaryTextColor
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2
        metadataLabel.font = AppTheme.font(.footnote)
        metadataLabel.textColor = AppTheme.secondaryTextColor
        metadataLabel.adjustsFontForContentSizeCategory = true
        metadataLabel.numberOfLines = 2
        accessoryType = .disclosureIndicator
    }

    func configure(document: GarageDocument, associationText: String? = nil) {
        nameLabel.text = document.displayName
        iconImageView.image = UIImage(systemName: document.mimeType == "application/pdf" ? "doc.richtext.fill" : "photo.fill")
        var metadata = [
            document.documentType.displayName,
            ByteCountFormatter.string(fromByteCount: document.fileSize, countStyle: .file)
        ]
        if let associationText { metadata.append(associationText) }
        metadataLabel.text = metadata.joined(separator: " • ")
        accessibilityLabel = ([document.displayName] + metadata).joined(separator: ", ")
        accessibilityHint = "Belge önizlemesini açar"
    }
}
