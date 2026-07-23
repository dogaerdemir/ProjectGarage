//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

enum AppTheme {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let standard: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let compact: CGFloat = 8
        static let control: CGFloat = 10
        static let card: CGFloat = 12
        static let pill: CGFloat = 18
    }

    enum Metrics {
        static let horizontalMargin: CGFloat = 16
        static let cardPadding: CGFloat = 14
        static let controlHeight: CGFloat = 48
        static let minimumTapTarget: CGFloat = 44
        static let borderWidth: CGFloat = 1
        static let pageTopInset: CGFloat = Spacing.small
        static let pageTitleToContentSpacing: CGFloat = Spacing.medium
        static let sectionTitleToContentSpacing: CGFloat = Spacing.medium
        static let pageSectionSpacing: CGFloat = Spacing.standard
        static let pageBottomInset: CGFloat = Spacing.large
        static let searchFieldHeight: CGFloat = 44
        static let pageTitleToSearchSpacing: CGFloat = 14
        static let searchToFilterSpacing: CGFloat = 19
        static let filterToContentSpacing: CGFloat = 18
        static let floatingButtonSize: CGFloat = 56
        static let floatingButtonTrailingInset: CGFloat = 20
        static let floatingButtonBottomInset: CGFloat = 18
        static let floatingContentBottomInset: CGFloat = 88
    }

    static let horizontalSpacing = Metrics.horizontalMargin
    static let cardCornerRadius = Radius.card

    static var accentColor: UIColor { UIColor(named: "AppAccent") ?? .systemBlue }
    static var backgroundColor: UIColor { UIColor(named: "AppBackground") ?? .systemGroupedBackground }
    static var surfaceColor: UIColor { UIColor(named: "CardBackground") ?? .secondarySystemGroupedBackground }
    static var inputColor: UIColor { UIColor(named: "InputBackground") ?? .tertiarySystemFill }
    static var borderColor: UIColor { UIColor(named: "Border") ?? .separator }
    static var primaryTextColor: UIColor { UIColor(named: "PrimaryText") ?? .label }
    static var secondaryTextColor: UIColor { UIColor(named: "SecondaryText") ?? .secondaryLabel }
    static var accentSoftColor: UIColor { UIColor(named: "AccentSoft") ?? accentColor.withAlphaComponent(0.12) }
    static var secondaryActionBackgroundColor: UIColor { UIColor(named: "SecondaryActionBackground") ?? accentColor.withAlphaComponent(0.18) }
    static var dangerColor: UIColor { UIColor(named: "Danger") ?? .systemRed }
    static var warningColor: UIColor { UIColor(named: "Warning") ?? .systemOrange }
    static var successColor: UIColor { UIColor(named: "Success") ?? .systemGreen }
    static var successActionColor: UIColor { UIColor(named: "SuccessAction") ?? .systemGreen }
    static var onAccentColor: UIColor { UIColor(named: "OnAccent") ?? .white }

    static func font(_ textStyle: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let pointSize: CGFloat = switch textStyle {
        case .largeTitle: 34
        case .title1: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption1: 12
        case .caption2: 11
        default: 17
        }
        let base = UIFont.systemFont(ofSize: pointSize, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    @MainActor static func stylePageTitle(_ label: UILabel) {
        label.font = font(.title1, weight: .bold)
        label.textColor = primaryTextColor
        label.textAlignment = .natural
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.accessibilityTraits = .header
    }

    @MainActor static func styleSearchField(_ textField: UISearchTextField) {
        textField.borderStyle = .none
        textField.background = nil
        textField.disabledBackground = nil
        textField.font = font(.body)
        textField.textColor = primaryTextColor
        textField.backgroundColor = inputColor
        textField.tintColor = accentColor
        textField.clipsToBounds = true
        textField.layer.cornerRadius = Metrics.searchFieldHeight / 2
        textField.layer.cornerCurve = .continuous
        textField.layer.borderWidth = Metrics.borderWidth
        let searchIconView = UIImageView(
            image: UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            )
        )
        searchIconView.frame = CGRect(x: 0, y: 0, width: 40, height: Metrics.searchFieldHeight)
        searchIconView.contentMode = .center
        searchIconView.tintColor = accentColor
        textField.leftView = searchIconView
        textField.leftViewMode = .always
        updateSearchFieldBorder(for: textField)
        if let placeholder = textField.placeholder {
            textField.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [
                    .font: font(.body),
                    .foregroundColor: secondaryTextColor
                ]
            )
        }
        textField.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (field: UISearchTextField, _) in
            updateSearchFieldBorder(for: field)
        }
    }

    @MainActor private static func updateSearchFieldBorder(for textField: UISearchTextField) {
        textField.layer.borderColor = borderColor.resolvedColor(with: textField.traitCollection).cgColor
    }

    @MainActor static func styleFloatingButton(_ button: UIButton, symbol: String = "plus") {
        button.configuration = floatingButtonConfiguration(symbol: symbol)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 5)
    }

    @MainActor static func apply() {
        UIView.appearance().tintColor = accentColor

        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = backgroundColor
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [.foregroundColor: primaryTextColor]
        navigationBar.largeTitleTextAttributes = [.foregroundColor: primaryTextColor]
        navigationBar.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: accentColor]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar

        let tabBarProxy = UITabBar.appearance()
        tabBarProxy.tintColor = accentColor
        tabBarProxy.unselectedItemTintColor = secondaryTextColor
        tabBarProxy.itemPositioning = .fill
        tabBarProxy.isTranslucent = true

        UITableView.appearance().backgroundColor = backgroundColor
        UITableView.appearance().separatorColor = borderColor
        UISwitch.appearance().onTintColor = accentColor
    }

    @MainActor static func styleCard(_ view: UIView) {
        view.backgroundColor = surfaceColor
        view.layer.cornerRadius = Radius.card
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = Metrics.borderWidth
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.025
        view.layer.shadowRadius = 7
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        updateCardBorder(for: view)
        view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            updateCardBorder(for: view)
        }
    }

    @MainActor private static func updateCardBorder(for view: UIView) {
        view.layer.borderColor = borderColor.resolvedColor(with: view.traitCollection).cgColor
    }

    static func styleList(_ tableView: UITableView) {
        tableView.backgroundColor = backgroundColor
        tableView.separatorColor = borderColor
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 64, bottom: 0, right: 16)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.sectionHeaderTopPadding = Spacing.standard
    }

    static func styleForm(_ tableView: UITableView) {
        tableView.backgroundColor = backgroundColor
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        tableView.sectionHeaderTopPadding = Spacing.large
        tableView.keyboardDismissMode = .onDrag
    }

    static func primaryButtonConfiguration(title: String, symbol: String? = nil) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = symbol.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = Spacing.small
        configuration.cornerStyle = .medium
        configuration.baseBackgroundColor = accentColor
        configuration.baseForegroundColor = onAccentColor
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font(.body, weight: .semibold)
            return attributes
        }
        return configuration
    }

    static func secondaryButtonConfiguration(title: String, symbol: String? = nil) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = symbol.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = Spacing.small
        configuration.cornerStyle = .medium
        configuration.baseBackgroundColor = surfaceColor
        configuration.baseForegroundColor = accentColor
        configuration.background.strokeColor = borderColor
        configuration.background.strokeWidth = Metrics.borderWidth
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font(.body, weight: .semibold)
            return attributes
        }
        return configuration
    }

    static func floatingButtonConfiguration(symbol: String = "plus") -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: symbol)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        configuration.baseBackgroundColor = accentColor
        configuration.baseForegroundColor = onAccentColor
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        return configuration
    }

    @MainActor static func styleSegmentedControl(_ control: UISegmentedControl) {
        control.selectedSegmentTintColor = accentColor
        control.backgroundColor = inputColor
        control.setTitleTextAttributes([.foregroundColor: primaryTextColor, .font: font(.footnote, weight: .medium)], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: onAccentColor, .font: font(.footnote, weight: .semibold)], for: .selected)
    }

    @MainActor static func styleFocusableBorderedSurface(_ view: UIView, isFocused: Bool) {
        view.backgroundColor = inputColor
        view.layer.cornerRadius = Radius.control
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = isFocused ? 1.5 : Metrics.borderWidth
        let color = isFocused ? accentColor : borderColor
        view.layer.borderColor = color.resolvedColor(with: view.traitCollection).cgColor
    }

    @MainActor static func styleBorderedSurface(
        _ view: UIView,
        backgroundColor: UIColor,
        cornerRadius: CGFloat = Radius.control
    ) {
        view.backgroundColor = backgroundColor
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = Metrics.borderWidth
        updateCardBorder(for: view)
        view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            updateCardBorder(for: view)
        }
    }
}
