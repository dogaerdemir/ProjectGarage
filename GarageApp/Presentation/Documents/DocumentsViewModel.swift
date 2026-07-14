//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class DocumentsViewModel {
    private let session: AppSession; private let documentRepository: DocumentRepository
    private(set) var documents: [GarageDocument] = []
    private var loadGeneration = 0
    var onChange: (() -> Void)?; var onError: ((Error) -> Void)?
    init(session: AppSession, documentRepository: DocumentRepository) { self.session = session; self.documentRepository = documentRepository }
    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        var vehicleID: UUID?

        do {
            try await session.reload()
            guard generation == loadGeneration else { return }
            guard let id = session.selectedVehicle?.id else {
                documents = []
                onChange?()
                return
            }
            vehicleID = id

            let documents = try await documentRepository.fetchDocuments(vehicleID: id)
            guard generation == loadGeneration, session.selectedVehicle?.id == id else { return }
            self.documents = documents
            onChange?()
        } catch {
            guard generation == loadGeneration else { return }
            guard vehicleID == nil || session.selectedVehicle?.id == vehicleID else { return }
            onError?(error)
        }
    }
}
