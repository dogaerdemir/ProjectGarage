//
//  Created by Doğa Erdemir on 24.07.2026.
//

import Foundation

enum AppNetworkConfiguration {
    static var vehicleCatalogBaseURL: URL? {
        httpsURL(forInfoKey: "VehicleCatalogBaseURL")
    }

    private static func httpsURL(forInfoKey key: String) -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: rawValue),
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil else {
            return nil
        }
        return url
    }
}
