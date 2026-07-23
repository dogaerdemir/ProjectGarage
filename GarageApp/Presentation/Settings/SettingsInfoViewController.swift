//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

@MainActor
final class SettingsInfoViewController: UIViewController {
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var symbolImageView: UIImageView!
    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var bodyLabel: UILabel!

    private let screenTitle: String
    private let symbolName: String
    private let body: String

    init(title: String, symbolName: String, body: String) {
        screenTitle = title
        self.symbolName = symbolName
        self.body = body
        super.init(nibName: "SettingsInfoViewController", bundle: .main)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
    }

    private func configureAppearance() {
        title = screenTitle
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = AppTheme.backgroundColor

        iconContainerView.backgroundColor = AppTheme.accentSoftColor
        iconContainerView.layer.cornerRadius = 32
        iconContainerView.layer.cornerCurve = .continuous
        iconContainerView.isAccessibilityElement = false

        symbolImageView.image = UIImage(systemName: symbolName)
        symbolImageView.tintColor = AppTheme.accentColor
        symbolImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        symbolImageView.isAccessibilityElement = false

        AppTheme.styleCard(cardView)
        bodyLabel.text = body
        bodyLabel.font = AppTheme.font(.body)
        bodyLabel.textColor = AppTheme.primaryTextColor
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.numberOfLines = 0
    }
}
