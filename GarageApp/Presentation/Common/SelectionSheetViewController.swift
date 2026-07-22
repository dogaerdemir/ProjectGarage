//
//  Created by Doğa Erdemir on 13.07.2026.
//

import UIKit

struct SelectionSheetOption {
    let title: String
    let subtitle: String?
    let symbolName: String?

    init(title: String, subtitle: String? = nil, symbolName: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
    }
}

@MainActor
final class SelectionSheetViewController: UIViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var cancelButton: UIButton!

    private let sheetTitle: String
    private let message: String?
    private let options: [SelectionSheetOption]
    private let selectedIndex: Int?
    private let onSelect: (Int) -> Void

    init(
        title: String,
        message: String? = nil,
        options: [SelectionSheetOption],
        selectedIndex: Int? = nil,
        onSelect: @escaping (Int) -> Void
    ) {
        sheetTitle = title
        self.message = message
        self.options = options
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        super.init(nibName: "SelectionSheetViewController", bundle: .main)
        modalPresentationStyle = .pageSheet
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configureSheet()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: SelectionSheetViewController, _) in
            controller.configureSheet()
            controller.sheetPresentationController?.invalidateDetents()
        }
    }

    private func configureAppearance() {
        view.backgroundColor = AppTheme.surfaceColor
        titleLabel.text = sheetTitle
        titleLabel.font = AppTheme.font(.title2, weight: .bold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        messageLabel.text = message
        messageLabel.isHidden = message == nil
        messageLabel.font = AppTheme.font(.subheadline)
        messageLabel.textColor = AppTheme.secondaryTextColor
        messageLabel.adjustsFontForContentSizeCategory = true

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppTheme.borderColor
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 16)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 58
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SelectionOption")

        var cancelConfiguration = UIButton.Configuration.gray()
        cancelConfiguration.title = "Vazgeç"
        cancelConfiguration.image = UIImage(systemName: "xmark")
        cancelConfiguration.imagePadding = AppTheme.Spacing.small
        cancelConfiguration.cornerStyle = .large
        cancelConfiguration.baseForegroundColor = AppTheme.secondaryTextColor
        cancelConfiguration.baseBackgroundColor = AppTheme.inputColor
        cancelConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        cancelConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.font(.body, weight: .semibold)
            return attributes
        }
        cancelButton.configuration = cancelConfiguration
        cancelButton.accessibilityHint = "Seçim yapmadan pencereyi kapatır"
    }

    private func configureSheet() {
        guard let sheet = sheetPresentationController else { return }
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = 28
            return
        }
        let rowHeight = options.contains(where: { $0.subtitle != nil }) ? 68.0 : 58.0
        let messageHeight = message == nil ? 0.0 : 42.0
        let desiredHeight = min(720.0, 154.0 + messageHeight + rowHeight * Double(options.count))
        let identifier = UISheetPresentationController.Detent.Identifier("selectionContent")
        sheet.detents = [.custom(identifier: identifier) { context in
            min(CGFloat(desiredHeight), context.maximumDetentValue * 0.92)
        }]
        sheet.selectedDetentIdentifier = identifier
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.preferredCornerRadius = 28
    }

    @IBAction private func cancelTapped() {
        dismiss(animated: true)
    }
}

extension SelectionSheetViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { options.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = options[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SelectionOption", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = option.title
        content.secondaryText = option.subtitle
        content.textProperties.font = AppTheme.font(.body, weight: .medium)
        content.textProperties.color = AppTheme.primaryTextColor
        content.secondaryTextProperties.font = AppTheme.font(.footnote)
        content.secondaryTextProperties.color = AppTheme.secondaryTextColor
        content.image = option.symbolName.flatMap(UIImage.init(systemName:))
        content.imageProperties.tintColor = AppTheme.accentColor
        content.imageProperties.reservedLayoutSize = CGSize(width: 28, height: 28)
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        cell.accessoryType = indexPath.row == selectedIndex ? .checkmark : .none
        cell.tintColor = AppTheme.accentColor
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = [option.title, option.subtitle].compactMap { $0 }.joined(separator: ", ")
        cell.accessibilityHint = "Seçmek için çift dokunun"
        cell.accessibilityTraits = indexPath.row == selectedIndex ? [.button, .selected] : .button
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dismiss(animated: true) { [onSelect] in onSelect(indexPath.row) }
    }
}

extension UIViewController {
    func presentSelectionSheet(
        title: String,
        message: String? = nil,
        options: [SelectionSheetOption],
        selectedIndex: Int? = nil,
        onSelect: @escaping (Int) -> Void
    ) {
        guard !options.isEmpty else { return }
        let controller = SelectionSheetViewController(
            title: title,
            message: message,
            options: options,
            selectedIndex: selectedIndex,
            onSelect: onSelect
        )
        present(controller, animated: true)
    }
}
