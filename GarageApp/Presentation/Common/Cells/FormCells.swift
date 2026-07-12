//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

class BaseFormCell: UITableViewCell {
    let fieldTitleLabel = UILabel()

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        fieldTitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        fieldTitleLabel.adjustsFontForContentSizeCategory = true
        fieldTitleLabel.textColor = UIColor(named: "SecondaryText")
        fieldTitleLabel.setContentHuggingPriority(.required, for: .horizontal)
    }
}

final class TextInputCell: BaseFormCell {
    let textField = UITextField()
    override func awakeFromNib() { super.awakeFromNib(); installRow(control: textField) }
}

final class DecimalInputCell: BaseFormCell {
    let textField = UITextField()
    override func awakeFromNib() {
        super.awakeFromNib(); textField.keyboardType = .decimalPad; installRow(control: textField)
    }
}

final class DatePickerCell: BaseFormCell {
    let datePicker = UIDatePicker()
    override func awakeFromNib() {
        super.awakeFromNib(); datePicker.preferredDatePickerStyle = .compact; installRow(control: datePicker)
    }
}

final class SelectionCell: BaseFormCell {
    let valueLabel = UILabel()
    override func awakeFromNib() {
        super.awakeFromNib(); accessoryType = .disclosureIndicator; installRow(control: valueLabel)
    }
}

final class ToggleCell: BaseFormCell {
    let toggle = UISwitch()
    override func awakeFromNib() { super.awakeFromNib(); installRow(control: toggle) }
}

final class MultilineTextCell: BaseFormCell {
    let textView = UITextView()
    override func awakeFromNib() {
        super.awakeFromNib(); textView.font = .preferredFont(forTextStyle: .body); installVertical(control: textView)
    }
}

final class AttachmentPickerCell: BaseFormCell {
    let actionButton = UIButton(type: .system)
    override func awakeFromNib() {
        super.awakeFromNib(); actionButton.setTitle("Belge Ekle", for: .normal); installRow(control: actionButton)
    }
}

private extension BaseFormCell {
    func installRow(control: UIView) {
        let stack = UIStackView(arrangedSubviews: [fieldTitleLabel, control])
        stack.axis = .horizontal; stack.alignment = .center; stack.spacing = 12
        install(stack)
    }

    func installVertical(control: UIView) {
        let stack = UIStackView(arrangedSubviews: [fieldTitleLabel, control])
        stack.axis = .vertical; stack.spacing = 6
        install(stack)
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
    }

    func install(_ stack: UIStackView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
}
