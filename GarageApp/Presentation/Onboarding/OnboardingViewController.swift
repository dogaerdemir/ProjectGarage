//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class OnboardingViewController: UIViewController, UIScrollViewDelegate {
    var onAddFirstVehicle: (() -> Void)?
    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let actionButton = UIButton(type: .system)
    private let pages = [
        ("car.2.fill", "Araç geçmişiniz tek yerde", "Bakım, yakıt, masraf ve kilometre kayıtlarınızı düzenli tutun."),
        ("bell.badge.fill", "Önemli tarihleri kaçırmayın", "Bakım, sigorta ve muayene için tarih veya kilometre hatırlatmaları oluşturun."),
        ("doc.text.image.fill", "Belgelerinizi kaybetmeyin", "Fatura, poliçe ve belgeleri ilgili kayıtlarla cihazınızda saklayın.")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "AppBackground")
        isModalInPresentation = true
        configureUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentSize = CGSize(width: scrollView.bounds.width * CGFloat(pages.count), height: scrollView.bounds.height)
        for (index, page) in scrollView.subviews.enumerated() where page.tag == 100 + index {
            page.frame = CGRect(x: CGFloat(index) * scrollView.bounds.width, y: 0, width: scrollView.bounds.width, height: scrollView.bounds.height)
        }
    }

    private func configureUI() {
        scrollView.isPagingEnabled = true; scrollView.showsHorizontalScrollIndicator = false; scrollView.delegate = self
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        for (index, data) in pages.enumerated() {
            let image = UIImageView(image: UIImage(systemName: data.0))
            image.tintColor = UIColor(named: "AppAccent"); image.contentMode = .scaleAspectFit
            image.widthAnchor.constraint(equalToConstant: 112).isActive = true
            image.heightAnchor.constraint(equalToConstant: 112).isActive = true
            let title = UILabel(); title.text = data.1; title.font = .preferredFont(forTextStyle: .title1)
            title.adjustsFontForContentSizeCategory = true; title.textAlignment = .center; title.numberOfLines = 0
            let message = UILabel(); message.text = data.2; message.font = .preferredFont(forTextStyle: .body)
            message.adjustsFontForContentSizeCategory = true; message.textAlignment = .center; message.numberOfLines = 0
            message.textColor = UIColor(named: "SecondaryText")
            let stack = UIStackView(arrangedSubviews: [image, title, message]); stack.axis = .vertical
            stack.alignment = .center; stack.spacing = 20; stack.tag = 100 + index
            scrollView.addSubview(stack)
        }

        pageControl.numberOfPages = pages.count; pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = UIColor(named: "AppAccent")
        pageControl.pageIndicatorTintColor = UIColor(named: "SecondaryText")
        actionButton.configuration = .filled(); actionButton.configuration?.cornerStyle = .large
        actionButton.setTitle("Devam", for: .normal); actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        view.addSubview(pageControl); view.addSubview(actionButton)
        pageControl.translatesAutoresizingMaskIntoConstraints = false; actionButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -16),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -16),
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    @objc private func actionTapped() {
        if pageControl.currentPage < pages.count - 1 {
            let next = pageControl.currentPage + 1
            scrollView.setContentOffset(CGPoint(x: CGFloat(next) * scrollView.bounds.width, y: 0), animated: true)
            pageControl.currentPage = next
            if next == pages.count - 1 { actionButton.setTitle("İlk Aracımı Ekle", for: .normal) }
        } else { onAddFirstVehicle?() }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(round(scrollView.contentOffset.x / max(scrollView.bounds.width, 1)))
        actionButton.setTitle(pageControl.currentPage == pages.count - 1 ? "İlk Aracımı Ekle" : "Devam", for: .normal)
    }
}
