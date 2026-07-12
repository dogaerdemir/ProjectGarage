//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

@MainActor
final class DocumentsViewModel {
    private let session: AppSession; private let documentRepository: DocumentRepository
    private(set) var documents: [GarageDocument] = []
    var onChange: (() -> Void)?; var onError: ((Error) -> Void)?
    init(session: AppSession, documentRepository: DocumentRepository) { self.session = session; self.documentRepository = documentRepository }
    func load() async { do { try await session.reload(); guard let id = session.selectedVehicle?.id else { documents = []; onChange?(); return }; documents = try await documentRepository.fetchDocuments(vehicleID: id); onChange?() } catch { onError?(error) } }
}
