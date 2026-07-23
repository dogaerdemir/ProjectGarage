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
    private var loadGeneration = 0
    var onChange: (() -> Void)?; var onError: ((Error) -> Void)?
    var query = "" { didSet { onChange?() } }
    var selectedTypes = Set(RecordType.timelineTypes) { didSet { onChange?() } }

    var selectedFilter: RecordType? {
        guard selectedTypes != Set(RecordType.timelineTypes), selectedTypes.count == 1 else { return nil }
        return selectedTypes.first
    }

    init(session: AppSession, recordRepository: VehicleRecordRepository, documentRepository: DocumentRepository) { self.session = session; self.recordRepository = recordRepository; self.documentRepository = documentRepository }

    func selectFilter(_ type: RecordType?) {
        selectedTypes = type.map { Set([$0]) } ?? Set(RecordType.timelineTypes)
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        var vehicleID: UUID?

        do {
            try await session.reload()
            guard generation == loadGeneration else { return }
            guard let id = session.selectedVehicle?.id else {
                records = []
                recordIDsWithDocuments = []
                lineItemSearchText = [:]
                onChange?()
                return
            }
            vehicleID = id

            async let fetchedRecords = recordRepository.fetchRecords(vehicleID: id, types: nil)
            async let fetchedDocuments = documentRepository.fetchDocuments(vehicleID: id)
            let (records, documents) = try await (fetchedRecords, fetchedDocuments)

            var searchText: [UUID: String] = [:]
            for record in records where record.recordType == .maintenance {
                guard generation == loadGeneration, session.selectedVehicle?.id == id else { return }
                searchText[record.id] = try await recordRepository.lineItems(recordID: record.id).map { [$0.name, $0.category ?? "", $0.notes ?? ""].joined(separator: " ") }.joined(separator: " ")
            }

            guard generation == loadGeneration, session.selectedVehicle?.id == id else { return }
            self.records = records
            recordIDsWithDocuments = Set(documents.compactMap(\.recordID))
            lineItemSearchText = searchText
            onChange?()
        } catch {
            guard generation == loadGeneration else { return }
            guard vehicleID == nil || session.selectedVehicle?.id == vehicleID else { return }
            onError?(error)
        }
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

@MainActor
final class RecordDetailViewModel {
    private let recordID: UUID
    private let vehicleID: UUID
    private let recordRepository: VehicleRecordRepository
    private let documentRepository: DocumentRepository
    private var loadGeneration = 0

    private(set) var record: VehicleRecord?
    private(set) var lineItems: [RecordLineItem] = []
    private(set) var documents: [GarageDocument] = []
    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(
        record: VehicleRecord,
        recordRepository: VehicleRecordRepository,
        documentRepository: DocumentRepository
    ) {
        recordID = record.id
        vehicleID = record.vehicleID
        self.record = record
        self.recordRepository = recordRepository
        self.documentRepository = documentRepository
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration

        do {
            async let fetchedRecord = recordRepository.record(id: recordID)
            async let fetchedLineItems = recordRepository.lineItems(recordID: recordID)
            async let fetchedDocuments = documentRepository.fetchDocuments(vehicleID: vehicleID)

            guard let record = try await fetchedRecord, record.vehicleID == vehicleID else {
                throw GarageError.notFound
            }
            let (lineItems, vehicleDocuments) = try await (fetchedLineItems, fetchedDocuments)
            guard generation == loadGeneration else { return }

            self.record = record
            self.lineItems = lineItems
            documents = vehicleDocuments.filter { $0.recordID == recordID }
            onChange?()
        } catch {
            guard generation == loadGeneration else { return }
            onError?(error)
        }
    }
}
