//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

extension RecordType {
    static var timelineTypes: [RecordType] { allCases.filter { $0 != .mileage } }
    static var costChartTypes: [RecordType] { [.maintenance, .fuel, .expense, .insurance, .inspection] }

    var displayName: String {
        switch self { case .maintenance: "Bakım"; case .fuel: "Yakıt"; case .expense: "Masraf"; case .insurance: "Sigorta / Kasko"; case .inspection: "Muayene / Kontrol"; case .mileage: "Kilometre"; case .note: "Not" }
    }
    var symbolName: String {
        switch self { case .maintenance: "wrench.and.screwdriver.fill"; case .fuel: "fuelpump.fill"; case .expense: "creditcard.fill"; case .insurance: "shield.fill"; case .inspection: "checkmark.seal.fill"; case .mileage: "gauge.with.dots.needle.67percent"; case .note: "note.text" }
    }
    var tintColor: UIColor {
        switch self { case .maintenance: .systemOrange; case .fuel: .systemGreen; case .expense: .systemPurple; case .insurance: .systemBlue; case .inspection: .systemTeal; case .mileage: .systemIndigo; case .note: .systemGray }
    }
}

extension ReminderStatus {
    var displayName: String {
        switch self { case .active: "Aktif"; case .approaching: "Yaklaşıyor"; case .overdue: "Gecikmiş"; case .completed: "Tamamlandı"; case .cancelled: "İptal edildi" }
    }
}

extension DocumentType {
    var displayName: String {
        switch self { case .serviceInvoice: "Servis faturası"; case .fuelReceipt: "Yakıt fişi"; case .insurancePolicy: "Sigorta poliçesi"; case .inspectionDocument: "Muayene belgesi"; case .warrantyDocument: "Garanti belgesi"; case .vehiclePhoto: "Araç fotoğrafı"; case .other: "Diğer" }
    }

    var symbolName: String {
        switch self {
        case .serviceInvoice: "wrench.and.screwdriver.fill"
        case .fuelReceipt: "fuelpump.fill"
        case .insurancePolicy: "shield.fill"
        case .inspectionDocument: "checkmark.seal.fill"
        case .warrantyDocument: "checkmark.shield.fill"
        case .vehiclePhoto: "car.side.fill"
        case .other: "doc.fill"
        }
    }
}
