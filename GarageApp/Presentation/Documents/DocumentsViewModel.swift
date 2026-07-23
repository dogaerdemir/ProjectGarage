//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class DocumentsViewModel {
    enum Filter: CaseIterable, Hashable {
        case all
        case serviceInvoice
        case fuelReceipt
        case insurancePolicy
        case inspectionDocument
        case warrantyDocument
        case vehiclePhoto
        case other

        var title: String {
            switch self {
            case .all: "Tümü"
            case .serviceInvoice: DocumentType.serviceInvoice.displayName
            case .fuelReceipt: DocumentType.fuelReceipt.displayName
            case .insurancePolicy: DocumentType.insurancePolicy.displayName
            case .inspectionDocument: DocumentType.inspectionDocument.displayName
            case .warrantyDocument: DocumentType.warrantyDocument.displayName
            case .vehiclePhoto: DocumentType.vehiclePhoto.displayName
            case .other: DocumentType.other.displayName
            }
        }

        fileprivate func contains(_ type: DocumentType) -> Bool {
            switch self {
            case .all:
                true
            case .serviceInvoice:
                type == .serviceInvoice
            case .fuelReceipt:
                type == .fuelReceipt
            case .insurancePolicy:
                type == .insurancePolicy
            case .inspectionDocument:
                type == .inspectionDocument
            case .warrantyDocument:
                type == .warrantyDocument
            case .vehiclePhoto:
                type == .vehiclePhoto
            case .other:
                type == .other
            }
        }
    }

    private let session: AppSession
    private let documentRepository: DocumentRepository
    private let recordRepository: VehicleRecordRepository?
    private(set) var allDocuments: [GarageDocument] = []
    private var recordsByID: [UUID: VehicleRecord] = [:]
    private var loadGeneration = 0

    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            onChange?()
        }
    }

    var selectedFilter: Filter = .all {
        didSet {
            guard selectedFilter != oldValue else { return }
            onChange?()
        }
    }

    init(
        session: AppSession,
        documentRepository: DocumentRepository,
        recordRepository: VehicleRecordRepository? = nil
    ) {
        self.session = session
        self.documentRepository = documentRepository
        self.recordRepository = recordRepository
    }

    var documents: [GarageDocument] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return allDocuments.filter { document in
            guard selectedFilter.contains(document.documentType) else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            let searchableValues = [
                document.displayName,
                document.documentType.displayName,
                associationText(for: document) ?? "",
                metadataText(for: document)
            ]
            return searchableValues.contains { $0.localizedCaseInsensitiveContains(normalizedQuery) }
        }
    }

    var hasDocuments: Bool { !allDocuments.isEmpty }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        var vehicleID: UUID?

        do {
            try await session.reload()
            guard generation == loadGeneration else { return }
            guard let id = session.selectedVehicle?.id else {
                allDocuments = []
                recordsByID = [:]
                onChange?()
                return
            }
            vehicleID = id

            let documents = try await documentRepository.fetchDocuments(vehicleID: id)
            let records: [VehicleRecord]
            if let recordRepository {
                records = try await recordRepository.fetchRecords(vehicleID: id, types: nil)
            } else {
                records = []
            }

            guard generation == loadGeneration, session.selectedVehicle?.id == id else { return }
            allDocuments = documents
            recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
            onChange?()
        } catch {
            guard generation == loadGeneration else { return }
            guard vehicleID == nil || session.selectedVehicle?.id == vehicleID else { return }
            onError?(error)
        }
    }

    func associationText(for document: GarageDocument) -> String? {
        if let recordID = document.recordID {
            if let record = recordsByID[recordID] {
                return "\(record.recordType.displayName) kaydına bağlı"
            }
            return "Kayda bağlı"
        }

        switch document.documentType {
        case .serviceInvoice, .fuelReceipt, .insurancePolicy, .warrantyDocument, .other:
            return "Genel belge"
        case .inspectionDocument, .vehiclePhoto:
            return nil
        }
    }

    func metadataText(for document: GarageDocument) -> String {
        if document.documentType == .vehiclePhoto, let vehicle = session.selectedVehicle {
            let description = [vehicle.make, vehicle.model]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !description.isEmpty { return description }
        }

        if let recordID = document.recordID, let record = recordsByID[recordID] {
            return AppFormatters.date.string(from: record.eventDate)
        }
        return AppFormatters.date.string(from: document.createdAt)
    }
}
