//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let isUITesting = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiTesting") }
        let container = DependencyContainer(inMemory: isUITesting)
        let coordinator = AppCoordinator(window: window, container: container)
        self.window = window; appCoordinator = coordinator; coordinator.start()
    }
}
