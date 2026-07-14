//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class OnboardingViewController: UIViewController, UIScrollViewDelegate {
    var onAddFirstVehicle: (() -> Void)?

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let actionButton = UIButton(type: .system)
    private var pageViews: [OnboardingPageView] = []

    private let pages = [
        ("car.2.fill", "Araç geçmişiniz tek yerde", "Bakım, yakıt, masraf ve kilometre kayıtlarınızı düzenli tutun."),
        ("bell.badge.fill", "Önemli tarihleri kaçırmayın", "Bakım, sigorta ve muayene için tarih veya kilometre hatırlatmaları oluşturun."),
        ("doc.text.image.fill", "Belgelerinizi kaybetmeyin", "Fatura, poliçe ve belgeleri ilgili kayıtlarla cihazınızda saklayın.")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.backgroundColor
        isModalInPresentation = true
        configureUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let pageSize = scrollView.bounds.size
        scrollView.contentSize = CGSize(
            width: pageSize.width * CGFloat(pageViews.count),
            height: pageSize.height
        )

        for (index, page) in pageViews.enumerated() {
            page.frame = CGRect(
                x: CGFloat(index) * pageSize.width,
                y: 0,
                width: pageSize.width,
                height: pageSize.height
            )
        }
    }

    private func configureUI() {
        scrollView.isPagingEnabled = true
        scrollView.isDirectionalLockEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.accessibilityLabel = "Project Garage tanıtımı"
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        for page in pages {
            let pageView = OnboardingPageView(symbol: page.0, title: page.1, message: page.2)
            scrollView.addSubview(pageView)
            pageViews.append(pageView)
        }

        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.allowsContinuousInteraction = false
        pageControl.currentPageIndicatorTintColor = AppTheme.accentColor
        pageControl.pageIndicatorTintColor = AppTheme.secondaryTextColor.withAlphaComponent(0.35)
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)

        configureActionButton()
        updateActionButton()

        view.addSubview(pageControl)
        view.addSubview(actionButton)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -12),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -16),

            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.horizontalSpacing),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.horizontalSpacing),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])
    }

    private func configureActionButton() {
        var configuration = AppTheme.primaryButtonConfiguration(title: "Devam", symbol: "arrow.right")
        configuration.imagePlacement = .trailing
        actionButton.configuration = configuration
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        actionButton.titleLabel?.numberOfLines = 0
        actionButton.titleLabel?.textAlignment = .center
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    private func updateActionButton() {
        let isLastPage = pageControl.currentPage == pages.count - 1
        var configuration = actionButton.configuration
        configuration?.title = isLastPage ? "İlk Aracımı Ekle" : "Devam"
        configuration?.image = UIImage(systemName: isLastPage ? "car.fill" : "arrow.right")
        actionButton.configuration = configuration
        actionButton.accessibilityHint = isLastPage
            ? "İlk araç ekleme ekranını açar"
            : "Sonraki tanıtım sayfasını gösterir"
    }

    private func selectPage(_ page: Int, animated: Bool) {
        let targetPage = min(max(page, 0), pages.count - 1)
        pageControl.currentPage = targetPage
        scrollView.setContentOffset(
            CGPoint(x: CGFloat(targetPage) * scrollView.bounds.width, y: 0),
            animated: animated
        )
        updateActionButton()
    }

    @objc private func actionTapped() {
        if pageControl.currentPage < pages.count - 1 {
            selectPage(pageControl.currentPage + 1, animated: true)
        } else {
            onAddFirstVehicle?()
        }
    }

    @objc private func pageControlChanged() {
        selectPage(pageControl.currentPage, animated: true)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        selectPage(page, animated: false)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateActionButton()
    }
}

private final class OnboardingPageView: UIView {
    private let pageScrollView = UIScrollView()
    private let contentContainer = UIView()
    private let brandLabel = UILabel()
    private let iconSurface = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let contentStack = UIStackView()
    private var iconWidthConstraint: NSLayoutConstraint!
    private var iconHeightConstraint: NSLayoutConstraint!

    init(symbol: String, title: String, message: String) {
        super.init(frame: .zero)
        configureUI(symbol: symbol, title: title, message: message)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (page: OnboardingPageView, _) in
            page.updateForContentSizeCategory()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    private func configureUI(symbol: String, title: String, message: String) {
        backgroundColor = .clear

        pageScrollView.showsHorizontalScrollIndicator = false
        pageScrollView.showsVerticalScrollIndicator = true
        pageScrollView.alwaysBounceHorizontal = false
        pageScrollView.alwaysBounceVertical = false
        pageScrollView.isDirectionalLockEnabled = true
        pageScrollView.contentInsetAdjustmentBehavior = .never
        addSubview(pageScrollView)
        pageScrollView.translatesAutoresizingMaskIntoConstraints = false

        pageScrollView.addSubview(contentContainer)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        brandLabel.text = "PROJECT GARAGE"
        brandLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: UIFont.systemFont(ofSize: 12, weight: .semibold)
        )
        brandLabel.adjustsFontForContentSizeCategory = true
        brandLabel.textColor = AppTheme.accentColor
        brandLabel.textAlignment = .center
        brandLabel.accessibilityLabel = "Project Garage"

        iconSurface.backgroundColor = AppTheme.accentSoftColor
        iconSurface.layer.cornerCurve = .continuous
        iconSurface.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 42, weight: .semibold)
        )
        iconView.tintColor = AppTheme.accentColor
        iconView.contentMode = .scaleAspectFit
        iconView.isAccessibilityElement = false

        titleLabel.text = title
        titleLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
            for: UIFont.systemFont(ofSize: 34, weight: .bold)
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.accessibilityTraits = .header

        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.textColor = AppTheme.secondaryTextColor

        contentStack.addArrangedSubview(brandLabel)
        contentStack.addArrangedSubview(iconSurface)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(messageLabel)
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 12
        contentContainer.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        iconWidthConstraint = iconSurface.widthAnchor.constraint(equalToConstant: 108)
        iconHeightConstraint = iconSurface.heightAnchor.constraint(equalToConstant: 108)
        let centerY = contentStack.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor)
        centerY.priority = .defaultHigh
        let fillsViewport = contentContainer.heightAnchor.constraint(equalTo: pageScrollView.frameLayoutGuide.heightAnchor)
        fillsViewport.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            pageScrollView.topAnchor.constraint(equalTo: topAnchor),
            pageScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pageScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pageScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentContainer.topAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: pageScrollView.contentLayoutGuide.bottomAnchor),
            contentContainer.widthAnchor.constraint(equalTo: pageScrollView.frameLayoutGuide.widthAnchor),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualTo: pageScrollView.frameLayoutGuide.heightAnchor),
            fillsViewport,

            contentStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: contentContainer.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor, constant: -8),
            centerY,

            titleLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            messageLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            iconWidthConstraint,
            iconHeightConstraint,

            iconView.centerXAnchor.constraint(equalTo: iconSurface.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconSurface.centerYAnchor),
            iconView.widthAnchor.constraint(equalTo: iconSurface.widthAnchor, multiplier: 0.46),
            iconView.heightAnchor.constraint(equalTo: iconSurface.heightAnchor, multiplier: 0.46)
        ])

        updateForContentSizeCategory()
    }

    private func updateForContentSizeCategory() {
        let usesAccessibilitySizes = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        pageScrollView.alwaysBounceVertical = usesAccessibilitySizes
        let iconSize: CGFloat = usesAccessibilitySizes ? 72 : 108
        iconWidthConstraint.constant = iconSize
        iconHeightConstraint.constant = iconSize
        iconSurface.layer.cornerRadius = usesAccessibilitySizes ? 22 : 32
        titleLabel.font = UIFontMetrics(forTextStyle: usesAccessibilitySizes ? .title1 : .largeTitle).scaledFont(
            for: UIFont.systemFont(ofSize: usesAccessibilitySizes ? 28 : 34, weight: .bold)
        )
        contentStack.setCustomSpacing(usesAccessibilitySizes ? 14 : 24, after: brandLabel)
        contentStack.setCustomSpacing(usesAccessibilitySizes ? 18 : 28, after: iconSurface)
        contentStack.setCustomSpacing(usesAccessibilitySizes ? 10 : 12, after: titleLabel)
    }
}
