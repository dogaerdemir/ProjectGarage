//
//  Created by Doğa Erdemir on 24.07.2026.
//

import Foundation
import UniformTypeIdentifiers

actor AssetBackedFileStorageService: FileStorageService {
    private let localStorage: FileStorageService
    private let assetRepository: AssetRepository

    init(
        localStorage: FileStorageService,
        assetRepository: AssetRepository
    ) {
        self.localStorage = localStorage
        self.assetRepository = assetRepository
    }

    func save(
        data: Data,
        vehicleID: UUID,
        recordID: UUID?,
        fileExtension: String
    ) async throws -> String {
        try AssetStorageLimits.validate(data: data)
        let relativePath = try await localStorage.save(
            data: data,
            vehicleID: vehicleID,
            recordID: recordID,
            fileExtension: fileExtension
        )

        do {
            try await assetRepository.upsert(
                data: data,
                vehicleID: vehicleID,
                recordID: recordID,
                relativePath: relativePath,
                mimeType: AssetMIMETypeResolver.mimeType(fileExtension: fileExtension)
            )
            return relativePath
        } catch {
            let assetError = error
            try? await localStorage.delete(relativePath: relativePath)
            throw assetError
        }
    }

    func read(relativePath: String) async throws -> Data {
        do {
            return try await localStorage.read(relativePath: relativePath)
        } catch {
            let localError = error
            do {
                if let assetData = try await assetRepository.data(relativePath: relativePath) {
                    return assetData
                }
            } catch {
                throw error
            }
            throw localError
        }
    }

    func delete(relativePath: String) async throws {
        var firstError: Error?

        do {
            try await localStorage.delete(relativePath: relativePath)
        } catch {
            firstError = error
        }

        do {
            try await assetRepository.delete(relativePath: relativePath)
        } catch {
            if firstError == nil {
                firstError = error
            }
        }

        if let firstError {
            throw firstError
        }
    }
}

enum AssetMIMETypeResolver {
    static func mimeType(fileExtension: String) -> String {
        let cleanExtension = fileExtension.trimmingCharacters(
            in: CharacterSet(charactersIn: ".")
        )
        guard !cleanExtension.isEmpty else {
            return "application/octet-stream"
        }
        return UTType(filenameExtension: cleanExtension)?.preferredMIMEType
            ?? "application/octet-stream"
    }

    static func mimeType(relativePath: String) -> String {
        mimeType(fileExtension: URL(fileURLWithPath: relativePath).pathExtension)
    }
}
