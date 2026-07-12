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
        rootURL = support.appendingPathComponent("ProjectGarage/Documents", isDirectory: true)
    }

    func save(data: Data, vehicleID: UUID, fileExtension: String) async throws -> String {
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
        do { return try Data(contentsOf: rootURL.appendingPathComponent(relativePath)) }
        catch { throw GarageError.fileOperation }
    }

    func delete(relativePath: String) async throws {
        let url = rootURL.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do { try fileManager.removeItem(at: url) }
        catch { throw GarageError.fileOperation }
    }
}
