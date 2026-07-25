//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CryptoKit
import Foundation

extension Notification.Name {
    static let vehicleCatalogDidUpdate = Notification.Name("vehicleCatalogDidUpdate")
}

protocol VehicleCatalogService: Sendable {
    func catalog() async throws -> VehicleCatalog
    func refreshIfAvailable() async
}

actor VersionedVehicleCatalogService: VehicleCatalogService {
    private enum Constants {
        static let bundledResourceName = "vehicle_catalog_tr"
        static let cacheDirectoryName = "ProjectGarage/Catalog"
        static let cachedFilename = "vehicle_catalog_tr.json"
        static let manifestPath = "vehicle-catalog/manifest.json"
        static let maximumManifestSize = 64 * 1_024
        static let maximumCatalogSize = 5 * 1_024 * 1_024
    }

    private let bundle: Bundle
    private let fileManager: FileManager
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let remoteBaseURL: URL?
    private var loadedCatalog: VehicleCatalog?

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        remoteBaseURL: URL? = AppNetworkConfiguration.vehicleCatalogBaseURL
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        self.session = session
        self.remoteBaseURL = remoteBaseURL
    }

    func catalog() async throws -> VehicleCatalog {
        if let loadedCatalog { return loadedCatalog }

        let bundled = try loadBundledCatalog()
        let cached = try? loadCachedCatalog()
        let compatibleCached = cached.flatMap {
            $0.schemaVersion == bundled.schemaVersion ? $0 : nil
        }
        let selected = [bundled, compatibleCached]
            .compactMap { $0 }
            .max { $0.catalogVersion < $1.catalogVersion } ?? bundled
        loadedCatalog = selected
        return selected
    }

    func refreshIfAvailable() async {
        guard let remoteBaseURL, isValidBaseURL(remoteBaseURL) else { return }

        do {
            let current = try await catalog()
            let manifestURL = baseDirectoryURL(remoteBaseURL)
                .appending(path: Constants.manifestPath)
            let manifestData = try await requestData(
                from: manifestURL,
                baseURL: remoteBaseURL,
                maximumSize: Constants.maximumManifestSize
            )
            let manifest = try decoder.decode(VehicleCatalogManifest.self, from: manifestData)
            guard manifest.schemaVersion == current.schemaVersion,
                  manifest.catalogVersion > current.catalogVersion,
                  let catalogURL = safeCatalogURL(path: manifest.catalogPath, baseURL: remoteBaseURL) else {
                return
            }

            let catalogData = try await requestData(
                from: catalogURL,
                baseURL: remoteBaseURL,
                maximumSize: Constants.maximumCatalogSize
            )
            if let expectedHash = manifest.sha256?.lowercased() {
                let actualHash = SHA256.hash(data: catalogData)
                    .map { String(format: "%02x", $0) }
                    .joined()
                guard actualHash == expectedHash else { return }
            }

            let downloaded = try decoder.decode(VehicleCatalog.self, from: catalogData)
            guard downloaded.schemaVersion == manifest.schemaVersion,
                  downloaded.catalogVersion == manifest.catalogVersion,
                  isValid(downloaded) else {
                return
            }

            try persist(catalogData)
            loadedCatalog = downloaded
            await MainActor.run {
                NotificationCenter.default.post(name: .vehicleCatalogDidUpdate, object: downloaded.catalogVersion)
            }
        } catch {
            // The bundled or last-known-good catalog remains authoritative offline.
        }
    }

    private func loadBundledCatalog() throws -> VehicleCatalog {
        guard let url = bundle.url(forResource: Constants.bundledResourceName, withExtension: "json") else {
            throw GarageError.persistence
        }
        let data = try Data(contentsOf: url)
        let catalog = try decoder.decode(VehicleCatalog.self, from: data)
        guard isValid(catalog) else { throw GarageError.persistence }
        return catalog
    }

    private func loadCachedCatalog() throws -> VehicleCatalog {
        let data = try Data(contentsOf: cacheURL)
        let catalog = try decoder.decode(VehicleCatalog.self, from: data)
        guard isValid(catalog) else { throw GarageError.persistence }
        return catalog
    }

    private func requestData(
        from url: URL,
        baseURL: URL,
        maximumSize: Int
    ) async throws -> Data {
        guard isSameOrigin(url, baseURL) else {
            throw URLError(.unsupportedURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadRevalidatingCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let finalURL = httpResponse.url,
              isSameOrigin(finalURL, baseURL),
              normalizedMIMEType(
                  httpResponse.value(forHTTPHeaderField: "Content-Type")
                      ?? httpResponse.mimeType
                      ?? ""
              ) == "application/json" else {
            throw URLError(.badServerResponse)
        }
        if httpResponse.expectedContentLength > Int64(maximumSize) {
            throw URLError(.dataLengthExceedsMaximum)
        }
        guard data.count <= maximumSize else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        return data
    }

    private func safeCatalogURL(path: String, baseURL: URL) -> URL? {
        let decodedPath = path.removingPercentEncoding ?? path
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !decodedPath.split(separator: "/").contains(".."),
              !decodedPath.contains("\\"),
              let relativeURL = URL(string: path),
              relativeURL.scheme == nil,
              relativeURL.host == nil,
              relativeURL.query == nil,
              relativeURL.fragment == nil,
              let candidate = URL(
                string: path,
                relativeTo: baseDirectoryURL(baseURL)
              )?.absoluteURL,
              candidate.scheme?.lowercased() == "https",
              isSameOrigin(candidate, baseURL) else {
            return nil
        }
        return candidate
    }

    private func isValidBaseURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host != nil
            && url.user == nil
            && url.password == nil
            && url.query == nil
            && url.fragment == nil
    }

    private func isValid(_ catalog: VehicleCatalog) -> Bool {
        guard catalog.schemaVersion > 0,
              catalog.catalogVersion > 0,
              ISO8601DateFormatter().date(from: catalog.updatedAt) != nil,
              (1...200).contains(catalog.makes.count) else {
            return false
        }

        var identifiers = Set<String>()
        var modelCount = 0
        for make in catalog.makes {
            guard isValidIdentifier(make.id),
                  identifiers.insert(make.id).inserted,
                  !make.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !make.models.isEmpty else {
                return false
            }
            modelCount += make.models.count
            for model in make.models {
                guard isValidIdentifier(model.id),
                      identifiers.insert(model.id).inserted,
                      !model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return false
                }
            }
        }
        return modelCount <= 2_000
    }

    private func isValidIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 96 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_.")
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }

    private func baseDirectoryURL(_ url: URL) -> URL {
        url.absoluteString.hasSuffix("/") ? url : url.appendingPathComponent("")
    }

    private func isSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && effectivePort(lhs) == effectivePort(rhs)
    }

    private func effectivePort(_ url: URL) -> Int? {
        if let port = url.port { return port }
        return url.scheme?.lowercased() == "https" ? 443 : nil
    }

    private func normalizedMIMEType(_ value: String) -> String {
        value
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func persist(_ data: Data) throws {
        let directory = cacheURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: [.atomic, .completeFileProtection])
    }

    private var cacheURL: URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appending(path: Constants.cacheDirectoryName, directoryHint: .isDirectory)
            .appending(path: Constants.cachedFilename)
    }
}
