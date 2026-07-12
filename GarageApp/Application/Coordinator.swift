//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

@MainActor
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    func start()
}

@MainActor
class BaseCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []

    func start() {
        preconditionFailure("Subclasses must implement start()")
    }

    func addChild(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }

    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
