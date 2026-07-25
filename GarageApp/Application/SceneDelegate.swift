//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?
    private var bootstrapTask: Task<Void, Never>?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        AppAppearanceController.shared.apply(to: window)
        let isUITesting = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiTesting") }
        self.window = window
        bootstrapTask = Task { @MainActor [weak self, weak window] in
            let container = await DependencyContainer.makeForApplication(
                inMemory: isUITesting
            )
            guard !Task.isCancelled, let self, let window else { return }
            if container.persistenceController.isCloudSyncActive {
                UIApplication.shared.registerForRemoteNotifications()
            }
            let coordinator = AppCoordinator(window: window, container: container)
            appCoordinator = coordinator
            coordinator.start()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        bootstrapTask?.cancel()
        bootstrapTask = nil
    }
}
