//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CoreData
import Foundation

struct LegacyAssetMigrationReport: Equatable, Sendable {
    let scannedCount: Int
    let mirroredCount: Int
    let alreadyMirroredCount: Int
    let failedRelativePaths: [String]

    var isComplete: Bool {
        failedRelativePaths.isEmpty
    }
}

actor LegacyAssetMigrator {
    private enum CandidateReference: Sendable {
        case vehicle
        case document
    }

    private struct Candidate: Sendable {
        let reference: CandidateReference
        let vehicleID: UUID
        let recordID: UUID?
        let relativePath: String
        let mimeType: String
    }

    private let persistence: PersistenceController
    private let legacyLocalStorage: FileStorageService
    private let assetRepository: AssetRepository

    init(
        persistence: PersistenceController,
        legacyLocalStorage: FileStorageService,
        assetRepository: AssetRepository
    ) {
        self.persistence = persistence
        self.legacyLocalStorage = legacyLocalStorage
        self.assetRepository = assetRepository
    }

    func mirrorLegacyFiles() async throws -> LegacyAssetMigrationReport {
        let candidates = try await fetchCandidates()
        var mirroredCount = 0
        var alreadyMirroredCount = 0
        var failedRelativePaths: [String] = []

        for candidate in candidates {
            do {
                guard try await isStillReferenced(candidate) else {
                    try await assetRepository.delete(
                        relativePath: candidate.relativePath
                    )
                    continue
                }

                if let existingAsset = try await assetRepository.asset(
                    relativePath: candidate.relativePath
                ),
                   let existingData = existingAsset.data {
                    guard try await isStillReferenced(candidate) else {
                        try await assetRepository.delete(
                            relativePath: candidate.relativePath
                        )
                        continue
                    }
                    if existingAsset.vehicleID != candidate.vehicleID
                        || existingAsset.recordID != candidate.recordID {
                        try await assetRepository.upsert(
                            data: existingData,
                            vehicleID: candidate.vehicleID,
                            recordID: candidate.recordID,
                            relativePath: candidate.relativePath,
                            mimeType: candidate.mimeType
                        )
                    }
                    if try await isStillReferenced(candidate) {
                        alreadyMirroredCount += 1
                    } else {
                        try await assetRepository.delete(
                            relativePath: candidate.relativePath
                        )
                    }
                    continue
                }

                let data = try await legacyLocalStorage.read(relativePath: candidate.relativePath)
                guard try await isStillReferenced(candidate) else {
                    try await assetRepository.delete(
                        relativePath: candidate.relativePath
                    )
                    continue
                }
                try await assetRepository.upsert(
                    data: data,
                    vehicleID: candidate.vehicleID,
                    recordID: candidate.recordID,
                    relativePath: candidate.relativePath,
                    mimeType: candidate.mimeType
                )
                if try await isStillReferenced(candidate) {
                    mirroredCount += 1
                } else {
                    try await assetRepository.delete(
                        relativePath: candidate.relativePath
                    )
                }
            } catch {
                if (try? await isStillReferenced(candidate)) == false {
                    try? await assetRepository.delete(
                        relativePath: candidate.relativePath
                    )
                    continue
                }
                failedRelativePaths.append(candidate.relativePath)
            }
        }

        // Legacy files intentionally remain in place. They are the local fallback until a
        // later, separately verified cleanup release removes them.
        return LegacyAssetMigrationReport(
            scannedCount: candidates.count,
            mirroredCount: mirroredCount,
            alreadyMirroredCount: alreadyMirroredCount,
            failedRelativePaths: failedRelativePaths
        )
    }

    private func fetchCandidates() async throws -> [Candidate] {
        let fetchedCandidates = try await persistence.read { context in
            var result: [Candidate] = []

            let vehicleRequest = NSFetchRequest<VehicleEntity>(entityName: "VehicleEntity")
            for vehicle in try context.fetch(vehicleRequest) {
                guard let vehicleID = vehicle.id,
                      let relativePath = vehicle.photoIdentifier,
                      !relativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    continue
                }

                result.append(
                    Candidate(
                        reference: .vehicle,
                        vehicleID: vehicleID,
                        recordID: nil,
                        relativePath: relativePath,
                        mimeType: AssetMIMETypeResolver.mimeType(relativePath: relativePath)
                    )
                )
            }

            let documentRequest = NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
            for document in try context.fetch(documentRequest) {
                let relativePath = document.localRelativePath
                guard let vehicleID = document.vehicleID,
                      !relativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }

                result.append(
                    Candidate(
                        reference: .document,
                        vehicleID: vehicleID,
                        recordID: document.recordID,
                        relativePath: relativePath,
                        mimeType: document.mimeType
                    )
                )
            }

            return result
        }

        var candidatesByPath: [String: Candidate] = [:]
        for candidate in fetchedCandidates {
            candidatesByPath[candidate.relativePath] = candidate
        }
        return candidatesByPath.values.sorted { $0.relativePath < $1.relativePath }
    }

    private func isStillReferenced(_ candidate: Candidate) async throws -> Bool {
        try await persistence.backgroundRead { context in
            guard try !CoreDataDeletionMarkerStore.contains(
                .vehicle,
                targetID: candidate.vehicleID,
                in: context
            ) else {
                return false
            }
            if let recordID = candidate.recordID {
                guard try !CoreDataDeletionMarkerStore.contains(
                    .record,
                    targetID: recordID,
                    in: context
                ) else {
                    return false
                }
            }

            switch candidate.reference {
            case .vehicle:
                let request = NSFetchRequest<VehicleEntity>(
                    entityName: "VehicleEntity"
                )
                request.predicate = NSCompoundPredicate(
                    andPredicateWithSubpredicates: [
                        NSPredicate(
                            format: "id == %@",
                            candidate.vehicleID as CVarArg
                        ),
                        NSPredicate(
                            format: "photoIdentifier == %@",
                            candidate.relativePath
                        )
                    ]
                )
                request.fetchLimit = 1
                return try context.count(for: request) > 0
            case .document:
                let request = NSFetchRequest<DocumentEntity>(
                    entityName: "DocumentEntity"
                )
                var predicates = [
                    NSPredicate(
                        format: "vehicleID == %@",
                        candidate.vehicleID as CVarArg
                    ),
                    NSPredicate(
                        format: "localRelativePath == %@",
                        candidate.relativePath
                    )
                ]
                if let recordID = candidate.recordID {
                    predicates.append(
                        NSPredicate(
                            format: "recordID == %@",
                            recordID as CVarArg
                        )
                    )
                } else {
                    predicates.append(NSPredicate(format: "recordID == nil"))
                }
                request.predicate = NSCompoundPredicate(
                    andPredicateWithSubpredicates: predicates
                )
                request.fetchLimit = 1
                return try context.count(for: request) > 0
            }
        }
    }
}
