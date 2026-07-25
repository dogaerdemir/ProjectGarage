//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CoreLocation
import Foundation

@MainActor
protocol NearbyPlacesService: AnyObject {
    func requestCurrentLocation() async throws -> CLLocation
    func search(category: NearbyCategory, around location: CLLocation) async throws -> [NearbyPlace]
}
enum NearbyServiceError: LocalizedError {
    case locationServicesDisabled
    case permissionDenied
    case locationUnavailable
    case requestInProgress
    case searchFailed(String)

    var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            "Konum Servisleri kapalı. Yakındaki işletmeleri görebilmek için Ayarlar’dan konumu açın."
        case .permissionDenied:
            "Konum izni verilmedi. Yakındaki işletmeleri görebilmek için Ayarlar’dan Project Garage konum iznini açın."
        case .locationUnavailable:
            "Konumunuz şu anda belirlenemedi. Açık bir alanda tekrar deneyin."
        case .requestInProgress:
            "Konum isteği hâlâ devam ediyor. Lütfen kısa bir süre sonra tekrar deneyin."
        case let .searchFailed(message):
            message.isEmpty
                ? "Yakındaki işletmeler aranırken bir sorun oluştu."
                : "Yakındaki işletmeler aranamadı. \(message)"
        }
    }

    var requiresSettings: Bool {
        switch self {
        case .locationServicesDisabled, .permissionDenied: true
        case .locationUnavailable, .requestInProgress, .searchFailed: false
        }
    }
}
