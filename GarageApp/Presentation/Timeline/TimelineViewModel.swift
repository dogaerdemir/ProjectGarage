//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class TimelineViewModel {
    struct Section { let title: String; let records: [VehicleRecord] }
    private let session: AppSession; private let recordRepository: VehicleRecordRepository; private let documentRepository: DocumentRepository
    private(set) var records: [VehicleRecord] = []
    private(set) var recordIDsWithDocuments: Set<UUID> = []
    private var lineItemSearchText: [UUID: String] = [:]
    var onChange: (() -> Void)?; var onError: ((Error) -> Void)?
    var query = "" { didSet { onChange?() } }
    var selectedTypes = Set(RecordType.allCases) { didSet { onChange?() } }

    init(session: AppSession, recordRepository: VehicleRecordRepository, documentRepository: DocumentRepository) { self.session = session; self.recordRepository = recordRepository; self.documentRepository = documentRepository }
    func load() async {
        do {
            try await session.reload(); guard let id = session.selectedVehicle?.id else { records = []; onChange?(); return }
            records = try await recordRepository.fetchRecords(vehicleID: id, types: nil)
            recordIDsWithDocuments = Set(try await documentRepository.fetchDocuments(vehicleID: id).compactMap(\.recordID))
            lineItemSearchText = [:]
            for record in records where record.recordType == .maintenance {
                lineItemSearchText[record.id] = try await recordRepository.lineItems(recordID: record.id).map { [$0.name, $0.category ?? "", $0.notes ?? ""].joined(separator: " ") }.joined(separator: " ")
            }
            onChange?()
        } catch { onError?(error) }
    }
    var sections: [Section] {
        let filtered = records.filter { record in
            selectedTypes.contains(record.recordType) && (query.isEmpty || [record.title, record.vendorName ?? "", record.notes ?? "", lineItemSearchText[record.id] ?? ""].contains { $0.localizedCaseInsensitiveContains(query) })
        }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "tr_TR"); formatter.dateFormat = "LLLL yyyy"
        return Dictionary(grouping: filtered) { formatter.string(from: $0.eventDate).capitalized(with: formatter.locale) }
            .map { Section(title: $0.key, records: $0.value.sorted { $0.eventDate > $1.eventDate }) }
            .sorted { ($0.records.first?.eventDate ?? .distantPast) > ($1.records.first?.eventDate ?? .distantPast) }
    }
}
