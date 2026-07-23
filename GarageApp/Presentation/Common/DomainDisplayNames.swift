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
    var selectionDisplayName: String {
        self == .maintenance ? "Bakım / Arıza" : displayName
    }
    var symbolName: String {
        switch self { case .maintenance: "wrench"; case .fuel: "fuelpump"; case .expense: "wallet.pass"; case .insurance: "shield"; case .inspection: "checkmark.seal"; case .mileage: "gauge.with.dots.needle.67percent"; case .note: "note.text" }
    }
    var tintColor: UIColor {
        switch self {
        case .maintenance: UIColor(red: 57 / 255, green: 118 / 255, blue: 172 / 255, alpha: 1)
        case .fuel: UIColor(red: 63 / 255, green: 142 / 255, blue: 98 / 255, alpha: 1)
        case .expense: UIColor(red: 201 / 255, green: 108 / 255, blue: 0, alpha: 1)
        case .insurance, .inspection, .mileage: AppTheme.accentColor
        case .note: UIColor(red: 141 / 255, green: 149 / 255, blue: 157 / 255, alpha: 1)
        }
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
