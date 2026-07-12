//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

struct AttachDocumentUseCase: Sendable {
    let repository: DocumentRepository
    let storage: FileStorageService

    func execute(
        data: Data, vehicleID: UUID, recordID: UUID?, type: DocumentType,
        displayName: String, mimeType: String, fileExtension: String
    ) async throws -> GarageDocument {
        let path = try await storage.save(data: data, vehicleID: vehicleID, fileExtension: fileExtension)
        let document = GarageDocument(
            vehicleID: vehicleID, recordID: recordID, documentType: type,
            displayName: displayName, mimeType: mimeType,
            fileSize: Int64(data.count), localRelativePath: path
        )
        do {
            try await repository.save(document)
            return document
        } catch {
            try? await storage.delete(relativePath: path)
            throw error
        }
    }
}

struct DeleteDocumentUseCase: Sendable {
    let repository: DocumentRepository
    let storage: FileStorageService

    func execute(documentID: UUID) async throws {
        guard let document = try await repository.document(id: documentID) else {
            throw GarageError.notFound
        }
        try await storage.delete(relativePath: document.localRelativePath)
        try await repository.delete(id: documentID)
    }
}
