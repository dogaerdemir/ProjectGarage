//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CoreLocation
import Foundation
import MapKit

enum NearbyCategory: String, CaseIterable, Hashable {
    case fuel
    case service
    case tire
    case carWash
    case inspection

    var title: String {
        switch self {
        case .fuel: "Yakıt"
        case .service: "Servis"
        case .tire: "Lastik"
        case .carWash: "Yıkama"
        case .inspection: "Muayene"
        }
    }

    var symbolName: String {
        switch self {
        case .fuel: "fuelpump.fill"
        case .service: "wrench.and.screwdriver.fill"
        case .tire: "circle.circle.fill"
        case .carWash: "drop.fill"
        case .inspection: "checkmark.seal.fill"
        }
    }

    var suggestedRecordType: RecordType {
        switch self {
        case .fuel: .fuel
        case .inspection: .inspection
        case .service, .tire, .carWash: .maintenance
        }
    }

    var searchQuery: String {
        switch self {
        case .fuel: "Akaryakıt istasyonu"
        case .service: "Oto servis"
        case .tire: "Lastikçi"
        case .carWash: "Oto yıkama"
        case .inspection: "Araç muayene istasyonu"
        }
    }

    var pointOfInterestCategories: [MKPointOfInterestCategory] {
        switch self {
        case .fuel: [.gasStation]
        case .service: [.automotiveRepair]
        case .tire, .carWash, .inspection: []
        }
    }
}

struct NearbyPlace: Identifiable {
    let id: String
    let name: String
    let address: String?
    let phoneNumber: String?
    let location: CLLocation
    let distance: CLLocationDistance
    let category: NearbyCategory
    let mapItem: MKMapItem

    var coordinate: CLLocationCoordinate2D { location.coordinate }
}
