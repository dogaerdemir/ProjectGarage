//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class OnboardingViewController: UIViewController, UIScrollViewDelegate {
    var onAddFirstVehicle: (() -> Void)?

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let actionButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    private let footerStack = UIStackView()
    private var pageViews: [OnboardingPageView] = []

    private let pages = [
        OnboardingPage(
            symbol: "car.2.fill",
            title: "Araç Geçmişin Tek Yerde",
            message: "Bakım, yakıt, masraf ve kilometre kayıtlarını düzenli tut."
        ),
        OnboardingPage(
            symbol: "bell.badge.fill",
            title: "Önemli Tarihleri Kaçırma",
            message: "Bakım, sigorta ve muayene tarihleri yaklaşınca haberdar ol."
        ),
        OnboardingPage(
            symbol: "doc.text.fill",
            title: "Belgelerin Hep Yanında",
            message: "Fatura, poliçe ve araç belgelerini\ngüvenle sakla."
        )
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

        pages.forEach { page in
            let pageView = OnboardingPageView(page: page)
            scrollView.addSubview(pageView)
            pageViews.append(pageView)
        }

        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.allowsContinuousInteraction = false
        pageControl.currentPageIndicatorTintColor = AppTheme.accentColor
        pageControl.pageIndicatorTintColor = AppTheme.secondaryTextColor.withAlphaComponent(0.30)
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)

        configureActionButton()
        configureBackButton()

        footerStack.axis = .vertical
        footerStack.spacing = 0
        footerStack.addArrangedSubview(actionButton)
        footerStack.addArrangedSubview(backButton)

        view.addSubview(pageControl)
        view.addSubview(footerStack)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        footerStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -8),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: footerStack.topAnchor, constant: -10),

            footerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            footerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            footerStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -2),
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        updateControls()
    }

    private func configureActionButton() {
        actionButton.configuration = AppTheme.primaryButtonConfiguration(title: "Devam")
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        actionButton.titleLabel?.numberOfLines = 0
        actionButton.titleLabel?.textAlignment = .center
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    private func configureBackButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Geri"
        configuration.baseForegroundColor = AppTheme.accentColor
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.font(.body, weight: .medium)
            return attributes
        }
        backButton.configuration = configuration
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.accessibilityHint = "Önceki tanıtım sayfasını gösterir"
    }

    private func updateControls() {
        let isFirstPage = pageControl.currentPage == 0
        let isLastPage = pageControl.currentPage == pages.count - 1
        var configuration = actionButton.configuration
        configuration?.title = isLastPage ? "İlk Aracımı Ekle" : "Devam"
        configuration?.image = nil
        actionButton.configuration = configuration
        backButton.alpha = isFirstPage ? 0 : 1
        backButton.isUserInteractionEnabled = !isFirstPage
        backButton.accessibilityElementsHidden = isFirstPage
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
        updateControls()
    }

    @objc private func actionTapped() {
        if pageControl.currentPage < pages.count - 1 {
            selectPage(pageControl.currentPage + 1, animated: true)
        } else {
            onAddFirstVehicle?()
        }
    }

    @objc private func backTapped() {
        selectPage(pageControl.currentPage - 1, animated: true)
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
        updateControls()
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String

    init(symbol: String, title: String, message: String) {
        self.symbol = symbol
        self.title = title
        self.message = message
    }
}

private final class OnboardingPageView: UIView {
    private let pageScrollView = UIScrollView()
    private let contentContainer = UIView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()

    init(page: OnboardingPage) {
        super.init(frame: .zero)
        configureUI(page: page)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    private func configureUI(page: OnboardingPage) {
        backgroundColor = .clear

        pageScrollView.showsHorizontalScrollIndicator = false
        pageScrollView.showsVerticalScrollIndicator = false
        pageScrollView.alwaysBounceHorizontal = false
        pageScrollView.alwaysBounceVertical = false
        pageScrollView.contentInsetAdjustmentBehavior = .never
        addSubview(pageScrollView)
        pageScrollView.translatesAutoresizingMaskIntoConstraints = false

        pageScrollView.addSubview(contentContainer)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 8
        contentContainer.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let symbolSurface = UIView()
        symbolSurface.backgroundColor = AppTheme.accentSoftColor
        symbolSurface.layer.cornerRadius = 44
        symbolSurface.layer.cornerCurve = .continuous
        let symbolView = UIImageView(image: UIImage(
            systemName: page.symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 58, weight: .medium)
        ))
        symbolView.tintColor = AppTheme.accentColor
        symbolView.contentMode = .scaleAspectFit
        symbolSurface.addSubview(symbolView)
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(symbolSurface)
        NSLayoutConstraint.activate([
            symbolSurface.widthAnchor.constraint(equalToConstant: 176),
            symbolSurface.heightAnchor.constraint(equalToConstant: 176),
            symbolView.centerXAnchor.constraint(equalTo: symbolSurface.centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: symbolSurface.centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 84),
            symbolView.heightAnchor.constraint(equalToConstant: 84)
        ])
        contentStack.setCustomSpacing(36, after: symbolSurface)

        titleLabel.text = page.title
        titleLabel.font = AppTheme.font(.title1, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.accessibilityTraits = .header

        messageLabel.text = page.message
        messageLabel.font = AppTheme.font(.body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.textColor = AppTheme.secondaryTextColor

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(messageLabel)

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

            contentStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: contentContainer.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),
            centerY,
            titleLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            messageLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (pageView: OnboardingPageView, _) in
            pageView.pageScrollView.alwaysBounceVertical = pageView.traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            pageView.pageScrollView.showsVerticalScrollIndicator = pageView.traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        }
    }
}
