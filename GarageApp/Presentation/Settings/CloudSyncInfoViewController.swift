//
//  Created by Doğa Erdemir on 24.07.2026.
//

import UIKit

@MainActor
final class CloudSyncInfoViewController: UIViewController {
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var symbolImageView: UIImageView!
    @IBOutlet private weak var statusCardView: UIView!
    @IBOutlet private weak var statusImageView: UIImageView!
    @IBOutlet private weak var statusTitleLabel: UILabel!
    @IBOutlet private weak var statusDetailLabel: UILabel!
    @IBOutlet private weak var informationCardView: UIView!
    @IBOutlet private weak var informationLabel: UILabel!
    @IBOutlet private weak var actionButton: UIButton!

    private let syncController: CloudSyncController

    init(syncController: CloudSyncController) {
        self.syncController = syncController
        super.init(nibName: "CloudSyncInfoViewController", bundle: .main)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncStatusDidChange),
            name: .cloudSyncStatusDidChange,
            object: syncController
        )
        syncController.refresh()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncController.refresh()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureAppearance() {
        title = "iCloud Eşitleme"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = AppTheme.backgroundColor

        iconContainerView.backgroundColor = AppTheme.accentSoftColor
        iconContainerView.layer.cornerRadius = 32
        iconContainerView.layer.cornerCurve = .continuous

        symbolImageView.image = UIImage(systemName: "icloud")
        symbolImageView.tintColor = AppTheme.accentColor
        symbolImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 28,
            weight: .regular
        )

        AppTheme.styleCard(statusCardView)
        AppTheme.styleCard(informationCardView)

        statusImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 24,
            weight: .semibold
        )
        statusTitleLabel.font = AppTheme.font(.headline, weight: .semibold)
        statusTitleLabel.textColor = AppTheme.primaryTextColor
        statusTitleLabel.adjustsFontForContentSizeCategory = true

        statusDetailLabel.font = AppTheme.font(.subheadline)
        statusDetailLabel.textColor = AppTheme.secondaryTextColor
        statusDetailLabel.adjustsFontForContentSizeCategory = true
        statusDetailLabel.numberOfLines = 0

        informationLabel.font = AppTheme.font(.body)
        informationLabel.textColor = AppTheme.primaryTextColor
        informationLabel.adjustsFontForContentSizeCategory = true
        informationLabel.numberOfLines = 0
        informationLabel.text = """
        iCloud eşitlemeyi açtığınızda araç bilgileriniz, plaka ve şasi numaranız, kayıtlarınız, fotoğraflarınız ve belgeleriniz Apple’ın iCloud hizmetindeki size özel veritabanına gönderilir.

        iCloud hesabı veya internet bağlantısı olmadığında uygulamayı yerel olarak kullanmaya devam edebilirsiniz. Bağlantı yeniden sağlandığında bekleyen değişiklikler sistem tarafından eşitlenir.
        """

        actionButton.addTarget(
            self,
            action: #selector(actionButtonTapped),
            for: .touchUpInside
        )
    }

    private func render() {
        let status = syncController.status
        statusImageView.image = UIImage(systemName: status.symbolName)
        statusTitleLabel.text = status.title
        statusDetailLabel.text = status.detail
        statusImageView.tintColor = statusColor(for: status)

        if !syncController.isAssetPreparationReady {
            let isPreparing = status == .preparingAssets
            actionButton.configuration = AppTheme.secondaryButtonConfiguration(
                title: isPreparing ? "Dosyalar Hazırlanıyor" : "Hazırlığı Yeniden Dene",
                symbol: isPreparing ? "externaldrive.badge.icloud" : "arrow.clockwise"
            )
            actionButton.isEnabled = !isPreparing
            actionButton.accessibilityHint = isPreparing
                ? "Mevcut fotoğraf ve belgelerin hazırlanmasını bekler."
                : "Fotoğraf ve belgeleri iCloud eşitlemesi için yeniden hazırlar."
            navigationItem.rightBarButtonItem = syncController.isEnabled
                ? UIBarButtonItem(
                    title: "Kapat",
                    style: .plain,
                    target: self,
                    action: #selector(disableFromNavigation)
                )
                : nil
        } else if syncController.isEnabled {
            actionButton.configuration = AppTheme.secondaryButtonConfiguration(
                title: "iCloud Eşitlemeyi Kapat",
                symbol: "icloud.slash"
            )
            actionButton.isEnabled = true
            actionButton.accessibilityHint = "Eşitleme tercihini kapatır."
            navigationItem.rightBarButtonItem = nil
        } else {
            actionButton.configuration = AppTheme.primaryButtonConfiguration(
                title: "iCloud Eşitlemeyi Aç",
                symbol: "icloud"
            )
            actionButton.isEnabled = true
            actionButton.accessibilityHint = "Verilerin iCloud ile eşitlenmesine onay verir."
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func statusColor(for status: CloudSyncStatus) -> UIColor {
        switch status {
        case .current:
            AppTheme.successColor
        case .preparingAssets, .checking, .syncing:
            AppTheme.accentColor
        case .unavailable, .restartRequired:
            AppTheme.warningColor
        case .disabled:
            AppTheme.secondaryTextColor
        }
    }

    @objc private func syncStatusDidChange() {
        render()
    }

    @objc private func actionButtonTapped() {
        if !syncController.isAssetPreparationReady {
            actionButton.isEnabled = false
            Task {
                await syncController.prepareLegacyAssets()
                render()
            }
        } else if syncController.isEnabled {
            confirmDisable()
        } else {
            confirmEnable()
        }
    }

    @objc private func disableFromNavigation() {
        confirmDisable()
    }

    private func confirmEnable() {
        let alert = UIAlertController(
            title: "iCloud Eşitlemeyi Aç",
            message: "Araç, kayıt, fotoğraf ve belge verilerinizin size özel iCloud veritabanına gönderilmesini onaylıyor musunuz?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
        alert.addAction(UIAlertAction(title: "Onayla ve Aç", style: .default) { [weak self] _ in
            guard let self else { return }
            if syncController.setEnabled(true) {
                render()
            }
        })
        present(alert, animated: true)
    }

    private func confirmDisable() {
        let alert = UIAlertController(
            title: "iCloud Eşitlemeyi Kapat",
            message: "Yerel veriler silinmez. Daha önce iCloud’a gönderilen veriler iCloud’da kalır. Değişiklik uygulama yeniden açıldığında uygulanır.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
        alert.addAction(UIAlertAction(title: "Eşitlemeyi Kapat", style: .destructive) { [weak self] _ in
            guard let self else { return }
            _ = syncController.setEnabled(false)
            render()
        })
        present(alert, animated: true)
    }
}
