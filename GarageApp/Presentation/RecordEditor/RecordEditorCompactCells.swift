//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

final class RecordEditorCompactRowCell: UITableViewCell {
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var valueContainerView: UIView!

    private var onTextChanged: ((String) -> Void)?
    private var onDateChanged: ((Date) -> Void)?
    private var onToggleChanged: ((Bool) -> Void)?
    private weak var activeTextField: UITextField?

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.surfaceColor
        contentView.backgroundColor = AppTheme.surfaceColor
        tintColor = AppTheme.accentColor
        titleLabel.font = AppTheme.font(.body)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        iconContainerView.backgroundColor = AppTheme.accentSoftColor
        iconContainerView.layer.cornerRadius = 15
        iconContainerView.layer.cornerCurve = .continuous
        iconImageView.tintColor = AppTheme.accentColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        reset()
    }

    func configureText(
        title: String,
        value: String,
        placeholder: String,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        suffix: String? = nil,
        onValueChanged: @escaping (String) -> Void
    ) {
        reset()
        configureTitle(title, symbol: nil)

        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .none
        textField.text = value
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: AppTheme.secondaryTextColor]
        )
        textField.font = AppTheme.font(.body)
        textField.adjustsFontForContentSizeCategory = true
        textField.textColor = AppTheme.primaryTextColor
        textField.tintColor = AppTheme.accentColor
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.accessibilityLabel = title
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        if keyboardType == .numberPad || keyboardType == .decimalPad {
            textField.inputAccessoryView = numericKeyboardToolbar()
        }
        if let suffix {
            let label = UILabel()
            label.text = "  \(suffix)"
            label.font = AppTheme.font(.subheadline, weight: .medium)
            label.textColor = AppTheme.secondaryTextColor
            label.sizeToFit()
            textField.rightView = label
            textField.rightViewMode = .always
        }

        install(textField)
        activeTextField = textField
        onTextChanged = onValueChanged
        selectionStyle = .none
    }

    func configureDate(title: String, date: Date, onValueChanged: @escaping (Date) -> Void) {
        reset()
        configureTitle(title, symbol: nil)

        let picker = UIDatePicker()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.date = date
        picker.tintColor = AppTheme.accentColor
        picker.accessibilityLabel = title
        picker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        install(picker, pinsLeading: false)
        onDateChanged = onValueChanged
        selectionStyle = .none
    }

    func configureSelection(
        title: String,
        value: String?,
        placeholder: String = "Seçin",
        symbol: String? = nil,
        showsChevron: Bool = true,
        enabled: Bool = true
    ) {
        reset()
        configureTitle(title, symbol: symbol)
        titleLabel.font = AppTheme.font(.body, weight: .medium)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = value ?? placeholder
        label.font = AppTheme.font(.body, weight: value == nil ? .regular : .medium)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = value == nil ? AppTheme.secondaryTextColor : AppTheme.primaryTextColor
        label.textAlignment = .right
        label.numberOfLines = 2
        install(label)
        accessoryType = showsChevron ? .disclosureIndicator : .none
        selectionStyle = .none
        contentView.alpha = enabled ? 1 : 0.72
        accessibilityLabel = title
        accessibilityValue = value ?? placeholder
        accessibilityTraits = enabled ? .button : .staticText
    }

    func configureToggle(
        title: String,
        isOn: Bool,
        symbol: String? = nil,
        onValueChanged: @escaping (Bool) -> Void
    ) {
        reset()
        configureTitle(title, symbol: symbol)

        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.isOn = isOn
        toggle.onTintColor = AppTheme.accentColor
        toggle.accessibilityLabel = title
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        install(toggle, pinsLeading: false)
        onToggleChanged = onValueChanged
        selectionStyle = .none
    }

    func configureAction(title: String, symbol: String, subtitle: String? = nil) {
        reset()
        configureTitle(title, symbol: symbol)
        titleLabel.font = AppTheme.font(.body, weight: .semibold)
        titleLabel.textColor = AppTheme.accentColor
        iconImageView.tintColor = AppTheme.accentColor

        if let subtitle {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = subtitle
            label.font = AppTheme.font(.footnote)
            label.textColor = AppTheme.secondaryTextColor
            label.textAlignment = .right
            label.numberOfLines = 2
            install(label)
        }
        selectionStyle = .none
        accessibilityTraits = .button
        accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
    }

    func updateTextValue(_ value: String) {
        activeTextField?.text = value
    }

    private func reset() {
        onTextChanged = nil
        onDateChanged = nil
        onToggleChanged = nil
        activeTextField = nil
        valueContainerView.subviews.forEach { $0.removeFromSuperview() }
        titleLabel.text = nil
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.font = AppTheme.font(.body)
        iconContainerView.isHidden = true
        iconImageView.image = nil
        contentView.alpha = 1
        accessoryType = .none
        selectionStyle = .none
        accessibilityLabel = nil
        accessibilityValue = nil
        accessibilityHint = nil
        accessibilityTraits = []
    }

    private func configureTitle(_ title: String, symbol: String?) {
        titleLabel.text = title
        iconContainerView.isHidden = symbol == nil
        iconImageView.image = symbol.flatMap(UIImage.init(systemName:))
    }

    private func install(_ view: UIView, pinsLeading: Bool = true) {
        valueContainerView.addSubview(view)
        let leading = pinsLeading
            ? view.leadingAnchor.constraint(equalTo: valueContainerView.leadingAnchor)
            : view.leadingAnchor.constraint(greaterThanOrEqualTo: valueContainerView.leadingAnchor)
        NSLayoutConstraint.activate([
            leading,
            view.trailingAnchor.constraint(equalTo: valueContainerView.trailingAnchor),
            view.topAnchor.constraint(greaterThanOrEqualTo: valueContainerView.topAnchor),
            view.bottomAnchor.constraint(lessThanOrEqualTo: valueContainerView.bottomAnchor),
            view.centerYAnchor.constraint(equalTo: valueContainerView.centerYAnchor)
        ])
    }

    private func numericKeyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Bitti", style: .done, target: self, action: #selector(doneEditing))
        ]
        return toolbar
    }

    @objc private func textChanged(_ sender: UITextField) {
        onTextChanged?(sender.text ?? "")
    }

    @objc private func dateChanged(_ sender: UIDatePicker) {
        onDateChanged?(sender.date)
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        onToggleChanged?(sender.isOn)
    }

    @objc private func doneEditing() {
        activeTextField?.resignFirstResponder()
    }
}

final class RecordEditorCompactNotesCell: UITableViewCell, UITextViewDelegate {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var textView: UITextView!
    @IBOutlet private weak var placeholderLabel: UILabel!

    private var onTextChanged: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.surfaceColor
        contentView.backgroundColor = AppTheme.surfaceColor
        selectionStyle = .none

        titleLabel.font = AppTheme.font(.body)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true

        textView.delegate = self
        textView.font = AppTheme.font(.body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = AppTheme.primaryTextColor
        textView.backgroundColor = AppTheme.inputColor
        textView.tintColor = AppTheme.accentColor
        textView.layer.cornerRadius = AppTheme.Radius.compact
        textView.layer.cornerCurve = .continuous
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 9, bottom: 10, right: 9)

        placeholderLabel.font = AppTheme.font(.body)
        placeholderLabel.textColor = AppTheme.secondaryTextColor
        placeholderLabel.adjustsFontForContentSizeCategory = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTextChanged = nil
        textView.text = nil
        placeholderLabel.isHidden = false
    }

    func configure(title: String, text: String, placeholder: String, onValueChanged: @escaping (String) -> Void) {
        titleLabel.text = title
        textView.text = text
        textView.accessibilityLabel = title
        placeholderLabel.text = placeholder
        placeholderLabel.isHidden = !text.isEmpty
        onTextChanged = onValueChanged
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        onTextChanged?(textView.text)
    }
}
