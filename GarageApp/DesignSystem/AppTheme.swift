//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

enum AppTheme {
    enum Spacing {
        static let xxSmall: CGFloat = 2
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let standard: CGFloat = 16
        static let section: CGFloat = 20
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let compact: CGFloat = 8
        static let control: CGFloat = 10
        static let card: CGFloat = 16
        static let sheet: CGFloat = 20
    }

    enum Metrics {
        static let horizontalMargin: CGFloat = 20
        static let cardPadding: CGFloat = 20
        static let controlHeight: CGFloat = 52
        static let minimumTapTarget: CGFloat = 44
        static let borderWidth: CGFloat = 1
        static let listIconSize: CGFloat = 42
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

    static var hairlineColor: UIColor { borderColor.withAlphaComponent(0.72) }
    static var scrimColor: UIColor { primaryTextColor.withAlphaComponent(0.08) }

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

    @MainActor static func apply() {
        UIView.appearance().tintColor = accentColor

        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = surfaceColor
        navigationBar.shadowColor = hairlineColor
        navigationBar.titleTextAttributes = [
            .foregroundColor: primaryTextColor,
            .font: font(.headline, weight: .semibold)
        ]
        navigationBar.largeTitleTextAttributes = [
            .foregroundColor: primaryTextColor,
            .font: font(.title1, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
        UINavigationBar.appearance().tintColor = accentColor

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = surfaceColor
        tabBar.shadowColor = hairlineColor
        let normalItemAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: secondaryTextColor,
            .font: font(.caption2, weight: .medium)
        ]
        let selectedItemAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: accentColor,
            .font: font(.caption2, weight: .semibold)
        ]
        [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance].forEach {
            $0.normal.iconColor = secondaryTextColor
            $0.normal.titleTextAttributes = normalItemAttributes
            $0.selected.iconColor = accentColor
            $0.selected.titleTextAttributes = selectedItemAttributes
        }
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
        UITabBar.appearance().tintColor = accentColor
        UITabBar.appearance().unselectedItemTintColor = secondaryTextColor

        UITableView.appearance().backgroundColor = backgroundColor
        UITableView.appearance().separatorColor = hairlineColor
        UITableViewCell.appearance().tintColor = accentColor
        let sectionLabel = UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self])
        sectionLabel.textColor = secondaryTextColor
        sectionLabel.font = font(.footnote, weight: .semibold)
        UISwitch.appearance().onTintColor = accentColor
        UIRefreshControl.appearance().tintColor = accentColor

        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: font(.body, weight: .semibold)],
            for: .normal
        )
    }

    @MainActor static func styleCard(_ view: UIView) {
        view.backgroundColor = surfaceColor
        view.layer.cornerRadius = Radius.card
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = Metrics.borderWidth
        view.layer.shadowOffset = CGSize(width: 0, height: 5)
        view.layer.shadowRadius = 12
        view.layer.masksToBounds = false
        updateCardAppearance(for: view)
        view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            updateCardAppearance(for: view)
        }
    }

    @MainActor private static func updateCardAppearance(for view: UIView) {
        view.layer.borderColor = borderColor.resolvedColor(with: view.traitCollection).cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = view.traitCollection.userInterfaceStyle == .dark ? 0.20 : 0.07
    }

    static func styleList(_ tableView: UITableView) {
        tableView.backgroundColor = backgroundColor
        tableView.separatorColor = hairlineColor
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 74, bottom: 0, right: Metrics.horizontalMargin)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        tableView.sectionHeaderTopPadding = Spacing.section
        tableView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: Metrics.horizontalMargin,
            bottom: 0,
            trailing: Metrics.horizontalMargin
        )
    }

    static func styleForm(_ tableView: UITableView) {
        tableView.backgroundColor = backgroundColor
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 104
        tableView.sectionHeaderTopPadding = Spacing.large
        tableView.keyboardDismissMode = .onDrag
        tableView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: Metrics.horizontalMargin,
            bottom: 0,
            trailing: Metrics.horizontalMargin
        )
    }

    static func primaryButtonConfiguration(title: String, symbol: String? = nil) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = symbol.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = Spacing.small
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = Radius.control
        configuration.baseBackgroundColor = accentColor
        configuration.baseForegroundColor = onAccentColor
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font(.body, weight: .semibold)
            return attributes
        }
        return configuration
    }

    static func secondaryButtonConfiguration(title: String, symbol: String? = nil) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = symbol.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = Spacing.small
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = Radius.control
        configuration.baseBackgroundColor = inputColor
        configuration.baseForegroundColor = primaryTextColor
        configuration.background.strokeColor = borderColor
        configuration.background.strokeWidth = Metrics.borderWidth
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font(.body, weight: .semibold)
            return attributes
        }
        return configuration
    }

    static func tonalButtonConfiguration(title: String, symbol: String? = nil) -> UIButton.Configuration {
        var configuration = secondaryButtonConfiguration(title: title, symbol: symbol)
        configuration.baseBackgroundColor = secondaryActionBackgroundColor
        configuration.baseForegroundColor = accentColor
        configuration.background.strokeColor = accentColor.withAlphaComponent(0.18)
        return configuration
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
        view.layer.borderColor = borderColor.resolvedColor(with: view.traitCollection).cgColor
        view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            view.layer.borderColor = borderColor.resolvedColor(with: view.traitCollection).cgColor
        }
    }

    static func styleSearchBar(_ searchBar: UISearchBar) {
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        let field = searchBar.searchTextField
        field.backgroundColor = inputColor
        field.textColor = primaryTextColor
        field.font = font(.body)
        field.layer.cornerRadius = Radius.control
        field.layer.cornerCurve = .continuous
        field.layer.borderWidth = Metrics.borderWidth
        field.layer.borderColor = borderColor.cgColor
        field.leftView?.tintColor = secondaryTextColor
        field.clipsToBounds = true
    }
}
