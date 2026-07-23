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
    private var tableHeightConstraint: NSLayoutConstraint?

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
            controller.updateRowMetrics()
            controller.tableView.reloadData()
            controller.configureSheet()
            controller.sheetPresentationController?.invalidateDetents()
        }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: SelectionSheetViewController, _) in
            controller.updateBorderColors()
        }
    }

    private func configureAppearance() {
        view.backgroundColor = AppTheme.surfaceColor
        titleLabel.text = sheetTitle
        titleLabel.font = UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: UIFont.systemFont(ofSize: 18, weight: .semibold)
        )
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
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 16)
        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableHeightConstraint?.priority = UILayoutPriority(999)
        updateRowMetrics()
        tableView.sectionHeaderTopPadding = 0
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.layer.cornerRadius = AppTheme.Radius.control
        tableView.layer.cornerCurve = .continuous
        tableView.layer.borderWidth = AppTheme.Metrics.borderWidth
        tableView.clipsToBounds = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SelectionOption")

        var cancelConfiguration = UIButton.Configuration.plain()
        cancelConfiguration.title = "Vazgeç"
        cancelConfiguration.cornerStyle = .medium
        cancelConfiguration.baseForegroundColor = AppTheme.primaryTextColor
        cancelConfiguration.baseBackgroundColor = AppTheme.surfaceColor
        cancelConfiguration.background.strokeColor = AppTheme.borderColor
        cancelConfiguration.background.strokeWidth = AppTheme.Metrics.borderWidth
        cancelConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        cancelConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.font(.body, weight: .medium)
            return attributes
        }
        cancelButton.configuration = cancelConfiguration
        cancelButton.accessibilityHint = "Seçim yapmadan pencereyi kapatır"
        updateBorderColors()
    }

    private func configureSheet() {
        guard let sheet = sheetPresentationController else { return }
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.preferredCornerRadius = 16

        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            return
        }

        let rowHeight = options.contains(where: { $0.subtitle != nil }) ? 64.0 : 48.0
        let messageHeight = message == nil ? 0.0 : 24.0
        let desiredHeight = min(720.0, 157.0 + messageHeight + rowHeight * Double(options.count))
        let identifier = UISheetPresentationController.Detent.Identifier("selectionContent")
        sheet.detents = [.custom(identifier: identifier) { context in
            min(CGFloat(desiredHeight), context.maximumDetentValue * 0.92)
        }]
        sheet.selectedDetentIdentifier = identifier
    }

    private func updateBorderColors() {
        tableView.layer.borderColor = AppTheme.borderColor.resolvedColor(with: traitCollection).cgColor
    }

    private func updateRowMetrics() {
        let compactRowHeight = options.contains(where: { $0.subtitle != nil }) ? 64.0 : 48.0
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        tableView.rowHeight = usesAccessibilityLayout ? UITableView.automaticDimension : compactRowHeight
        tableView.estimatedRowHeight = compactRowHeight
        tableHeightConstraint?.isActive = !usesAccessibilityLayout
        tableHeightConstraint?.constant = compactRowHeight * CGFloat(options.count)
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
        content.textProperties.font = AppTheme.font(.callout, weight: .regular)
        content.textProperties.color = AppTheme.primaryTextColor
        content.secondaryTextProperties.font = AppTheme.font(.footnote)
        content.secondaryTextProperties.color = AppTheme.secondaryTextColor
        content.image = option.symbolName.flatMap(UIImage.init(systemName:))
        content.imageProperties.tintColor = AppTheme.secondaryTextColor
        content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        content.imageProperties.reservedLayoutSize = CGSize(width: 30, height: 30)
        content.imageToTextPadding = AppTheme.Spacing.medium
        content.textToSecondaryTextVerticalPadding = AppTheme.Spacing.xSmall
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: AppTheme.Spacing.small,
            leading: AppTheme.Spacing.standard,
            bottom: AppTheme.Spacing.small,
            trailing: AppTheme.Spacing.small
        )
        cell.contentConfiguration = content
        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = indexPath.row == selectedIndex ? AppTheme.accentSoftColor : .clear
        cell.backgroundConfiguration = background
        cell.backgroundColor = .clear
        let selectedBackground = UIView()
        selectedBackground.backgroundColor = AppTheme.inputColor
        cell.selectedBackgroundView = selectedBackground
        cell.accessoryType = .disclosureIndicator
        cell.tintColor = AppTheme.secondaryTextColor
        cell.separatorInset = indexPath.row == options.count - 1
            ? UIEdgeInsets(top: 0, left: .greatestFiniteMagnitude, bottom: 0, right: 0)
            : UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 16)
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
