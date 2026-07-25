//
//  Created by Doğa Erdemir on 25.07.2026.
//

import UIKit

enum AppAppearanceMode: String, CaseIterable {
    case light
    case dark
    case system

    var title: String {
        switch self {
        case .light: "Açık"
        case .dark: "Koyu"
        case .system: "Cihaz"
        }
    }

    var symbolName: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        case .system: "circle.lefthalf.filled"
        }
    }

    fileprivate var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: .unspecified
        }
    }
}

@MainActor
final class AppAppearanceController {
    static let shared = AppAppearanceController()

    private let defaults: UserDefaults
    private let preferenceKey = "appAppearanceMode"

    var mode: AppAppearanceMode {
        get {
            guard let rawValue = defaults.string(forKey: preferenceKey),
                  let mode = AppAppearanceMode(rawValue: rawValue) else {
                return .system
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: preferenceKey)
        }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = mode.interfaceStyle
    }

    func update(_ mode: AppAppearanceMode) {
        self.mode = mode
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { apply(to: $0) }
    }
}
