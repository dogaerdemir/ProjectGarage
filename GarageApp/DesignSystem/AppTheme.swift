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
        static let compact: CGFloat = 10
        static let control: CGFloat = 12
        static let card: CGFloat = 18
    }

    enum Metrics {
        static let horizontalMargin: CGFloat = 16
        static let cardPadding: CGFloat = 18
        static let controlHeight: CGFloat = 50
        static let minimumTapTarget: CGFloat = 44
        static let borderWidth: CGFloat = 1
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

    @MainActor static func apply() {
        UIView.appearance().tintColor = accentColor

        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = backgroundColor
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [.foregroundColor: primaryTextColor]
        navigationBar.largeTitleTextAttributes = [.foregroundColor: primaryTextColor]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = surfaceColor
        tabBar.shadowColor = borderColor
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
        UITabBar.appearance().tintColor = accentColor
        UITabBar.appearance().unselectedItemTintColor = secondaryTextColor

        UITableView.appearance().backgroundColor = backgroundColor
        UITableView.appearance().separatorColor = borderColor
        UISwitch.appearance().onTintColor = accentColor
    }

    @MainActor static func styleCard(_ view: UIView) {
        view.backgroundColor = surfaceColor
        view.layer.cornerRadius = Radius.card
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = Metrics.borderWidth
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
        configuration.cornerStyle = .large
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
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = symbol.flatMap(UIImage.init(systemName:))
        configuration.imagePadding = Spacing.small
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = secondaryActionBackgroundColor
        configuration.baseForegroundColor = accentColor
        configuration.background.strokeColor = accentColor.withAlphaComponent(0.20)
        configuration.background.strokeWidth = Metrics.borderWidth
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font(.body, weight: .semibold)
            return attributes
        }
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
        updateCardBorder(for: view)
        view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            updateCardBorder(for: view)
        }
    }
}
