//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

enum FilterPillStyle {
    static let height: CGFloat = 36
    static let spacing: CGFloat = 8

    static func configuration(title: String, isSelected: Bool) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = isSelected ? AppTheme.accentColor : AppTheme.surfaceColor
        configuration.baseForegroundColor = isSelected ? AppTheme.onAccentColor : AppTheme.primaryTextColor
        configuration.background.strokeColor = isSelected ? AppTheme.accentColor : AppTheme.borderColor
        configuration.background.strokeWidth = AppTheme.Metrics.borderWidth
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 7,
            leading: 16,
            bottom: 7,
            trailing: 16
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.font(.footnote, weight: isSelected ? .semibold : .medium)
            return attributes
        }
        return configuration
    }
}
