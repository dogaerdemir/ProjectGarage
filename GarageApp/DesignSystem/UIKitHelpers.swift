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
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()

    init(symbol: String, title: String, message: String) {
        super.init(frame: .zero)
        imageView.image = UIImage(systemName: symbol)
        imageView.tintColor = UIColor(named: "SecondaryText")
        imageView.contentMode = .scaleAspectFit
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = UIColor(named: "SecondaryText")
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [imageView, titleLabel, messageLabel])
        stack.axis = .vertical; stack.alignment = .center; stack.spacing = 12
        addSubview(stack); stack.pinToEdges(of: self)
        imageView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 56).isActive = true
        isAccessibilityElement = true
        accessibilityLabel = "\(title). \(message)"
    }

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
