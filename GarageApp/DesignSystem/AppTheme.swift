//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

enum AppTheme {
    static let horizontalSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16

    @MainActor static func apply() {
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UITabBar.appearance().tintColor = UIColor(named: "AppAccent")
    }
}
