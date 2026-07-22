//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

extension UIView {
    func pinToEdges(of view: UIView, insets: NSDirectionalEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.leading),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.trailing),
            topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom)
        ])
    }
}

extension UIViewController {
    func presentError(_ error: Error) {
        let alert = UIAlertController(title: "Bir sorun oluştu", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }

    func confirm(title: String, message: String, destructiveTitle: String, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
        alert.addAction(UIAlertAction(title: destructiveTitle, style: .destructive) { _ in action() })
        present(alert, animated: true)
    }
}

final class EmptyStateView: UIView {
    private let panelView = UIView()
    private let iconContainer = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var action: (() -> Void)?

    init(symbol: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        super.init(frame: .zero)
        self.action = action
        backgroundColor = .clear
        imageView.image = UIImage(systemName: symbol)
        imageView.tintColor = AppTheme.accentColor
        imageView.contentMode = .scaleAspectFit
        iconContainer.backgroundColor = AppTheme.accentSoftColor
        iconContainer.layer.cornerRadius = AppTheme.Radius.control
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 52),
            iconContainer.heightAnchor.constraint(equalToConstant: 52),
            imageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 25),
            imageView.heightAnchor.constraint(equalToConstant: 25)
        ])
        titleLabel.text = title
        titleLabel.font = AppTheme.font(.title3, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.numberOfLines = 0
        messageLabel.text = message
        messageLabel.font = AppTheme.font(.subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = AppTheme.secondaryTextColor
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        var arrangedSubviews: [UIView] = [iconContainer, titleLabel, messageLabel]
        if let actionTitle {
            actionButton.configuration = AppTheme.tonalButtonConfiguration(title: actionTitle)
            actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: AppTheme.Metrics.minimumTapTarget).isActive = true
            arrangedSubviews.append(actionButton)
        }
        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = AppTheme.Spacing.small
        stack.setCustomSpacing(AppTheme.Spacing.standard, after: messageLabel)
        AppTheme.styleCard(panelView)
        addSubview(panelView)
        panelView.addSubview(stack)
        stack.pinToEdges(
            of: panelView,
            insets: NSDirectionalEdgeInsets(
                top: AppTheme.Spacing.large,
                leading: AppTheme.Spacing.large,
                bottom: AppTheme.Spacing.large,
                trailing: AppTheme.Spacing.large
            )
        )
        panelView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            panelView.centerXAnchor.constraint(equalTo: centerXAnchor),
            panelView.centerYAnchor.constraint(equalTo: centerYAnchor),
            panelView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: AppTheme.Metrics.horizontalMargin),
            trailingAnchor.constraint(greaterThanOrEqualTo: panelView.trailingAnchor, constant: AppTheme.Metrics.horizontalMargin),
            panelView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: AppTheme.Spacing.large),
            bottomAnchor.constraint(greaterThanOrEqualTo: panelView.bottomAnchor, constant: AppTheme.Spacing.large),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 310)
        ])
        isAccessibilityElement = actionTitle == nil
        accessibilityLabel = "\(title). \(message)"
    }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 292) }

    @objc private func actionTapped() { action?() }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

final class LoadingView: UIView {
    private let indicator = UIActivityIndicatorView(style: .medium)
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(indicator)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        indicator.startAnimating()
        accessibilityLabel = "Yükleniyor"
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

final class HairlineView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppTheme.hairlineColor
        heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

final class PageHeaderView: UIView {
    init(
        title: String,
        message: String? = nil,
        accessoryView: UIView? = nil,
        horizontalInset: CGFloat = AppTheme.Metrics.horizontalMargin
    ) {
        super.init(frame: .zero)
        backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.font(.title1, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        let textStack = UIStackView(arrangedSubviews: [titleLabel])
        textStack.axis = .vertical
        textStack.spacing = AppTheme.Spacing.xSmall

        if let message {
            let messageLabel = UILabel()
            messageLabel.text = message
            messageLabel.font = AppTheme.font(.subheadline)
            messageLabel.textColor = AppTheme.secondaryTextColor
            messageLabel.adjustsFontForContentSizeCategory = true
            messageLabel.numberOfLines = 0
            textStack.addArrangedSubview(messageLabel)
        }

        let accentRail = UIView()
        accentRail.backgroundColor = AppTheme.accentColor
        accentRail.layer.cornerRadius = 2
        accentRail.layer.cornerCurve = .continuous
        accentRail.widthAnchor.constraint(equalToConstant: 4).isActive = true

        let titleRow = UIStackView(arrangedSubviews: [accentRail, textStack])
        titleRow.axis = .horizontal
        titleRow.alignment = .fill
        titleRow.spacing = AppTheme.Spacing.medium

        var views: [UIView] = [titleRow]
        if let accessoryView {
            views.append(accessoryView)
        }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = AppTheme.Spacing.medium
        addSubview(stack)
        stack.pinToEdges(
            of: self,
            insets: NSDirectionalEdgeInsets(
                top: AppTheme.Spacing.small,
                leading: horizontalInset,
                bottom: AppTheme.Spacing.medium,
                trailing: horizontalInset
            )
        )
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

extension UITableView {
    func showEmptyState(_ emptyState: EmptyStateView?, when isEmpty: Bool) {
        backgroundView = isEmpty ? emptyState : nil
    }

    func updateTableHeaderHeightIfNeeded() {
        guard let header = tableHeaderView, bounds.width > 0 else { return }
        let fittingSize = header.systemLayoutSizeFitting(
            CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        guard abs(header.frame.width - bounds.width) > 0.5 || abs(header.frame.height - fittingSize.height) > 0.5 else { return }
        header.frame = CGRect(x: 0, y: 0, width: bounds.width, height: fittingSize.height)
        tableHeaderView = header
    }
}
