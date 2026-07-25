//
//  Created by Doğa Erdemir on 24.07.2026.
//

import UIKit

@MainActor
final class VehicleBrandLogoService {
    static let shared = VehicleBrandLogoService()

    private init() {}

    func logo(forMakeID makeID: String) async -> UIImage? {
        guard Self.isSafeIdentifier(makeID) else { return nil }
        return UIImage(named: "BrandLogo-\(makeID)")?.withRenderingMode(.alwaysOriginal)
    }

    private static func isSafeIdentifier(_ identifier: String) -> Bool {
        !identifier.isEmpty && identifier.unicodeScalars.allSatisfy {
            CharacterSet.lowercaseLetters
                .union(.decimalDigits)
                .union(CharacterSet(charactersIn: "-"))
                .contains($0)
        }
    }
}
