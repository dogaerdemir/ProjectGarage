//
//  Created by Doğa Erdemir on 12.07.2026.
//

import Foundation

actor LocalFileStorageService: FileStorageService {
    private let fileManager: FileManager
    private let rootURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootURL = support.appendingPathComponent("OtoHafiza/Documents", isDirectory: true)
    }

    func save(
        data: Data,
        vehicleID: UUID,
        recordID: UUID?,
        fileExtension: String
    ) async throws -> String {
        let folder = rootURL.appendingPathComponent(vehicleID.uuidString, isDirectory: true)
        let cleanExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let filename = UUID().uuidString + (cleanExtension.isEmpty ? "" : ".\(cleanExtension)")
        let destination = folder.appendingPathComponent(filename)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: destination, options: [.atomic, .completeFileProtection])
            return "\(vehicleID.uuidString)/\(filename)"
        } catch {
            throw GarageError.fileOperation
        }
    }

    func read(relativePath: String) async throws -> Data {
        do { return try Data(contentsOf: try resolvedURL(relativePath: relativePath)) }
        catch { throw GarageError.fileOperation }
    }

    func delete(relativePath: String) async throws {
        let url = try resolvedURL(relativePath: relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do { try fileManager.removeItem(at: url) }
        catch { throw GarageError.fileOperation }
    }

    private func resolvedURL(relativePath: String) throws -> URL {
        let decodedPath = relativePath.removingPercentEncoding ?? relativePath
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !decodedPath.contains("\\"),
              !decodedPath.split(separator: "/").contains("..") else {
            throw GarageError.fileOperation
        }

        let root = rootURL.standardizedFileURL
        let candidate = root
            .appendingPathComponent(relativePath)
            .standardizedFileURL
        guard candidate.path.hasPrefix(root.path + "/") else {
            throw GarageError.fileOperation
        }
        return candidate
    }
}
