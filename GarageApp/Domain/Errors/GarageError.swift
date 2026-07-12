//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

enum GarageError: LocalizedError, Equatable {
    case validation(String)
    case mileageCannotDecrease(current: Int64)
    case notFound
    case persistence
    case fileOperation
    case notificationPermissionDenied
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .validation(let message): message
        case .mileageCannotDecrease(let current):
            "Kilometre mevcut değerden (\(current) km) düşük olamaz."
        case .notFound: "İstenen kayıt bulunamadı."
        case .persistence: "Veriler kaydedilirken bir sorun oluştu."
        case .fileOperation: "Belge işlenirken bir sorun oluştu."
        case .notificationPermissionDenied: "Bildirim izni verilmedi. Hatırlatma uygulama içinde görünmeye devam edecek."
        case .insufficientData: "Bu hesaplama için yeterli veri yok."
        }
    }
}
