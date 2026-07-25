//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CoreLocation
import Foundation
import MapKit

@MainActor
final class MapKitNearbyPlacesService: NSObject, NearbyPlacesService {
    private let searchRadius: CLLocationDistance = 20_000
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return manager
    }()

    func requestCurrentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw NearbyServiceError.locationServicesDisabled
        }
        guard authorizationContinuation == nil, locationContinuation == nil else {
            throw NearbyServiceError.requestInProgress
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            let granted = await requestWhenInUseAuthorization()
            guard granted else { throw NearbyServiceError.permissionDenied }
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .denied, .restricted:
            throw NearbyServiceError.permissionDenied
        @unknown default:
            throw NearbyServiceError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    func search(category: NearbyCategory, around location: CLLocation) async throws -> [NearbyPlace] {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: searchRadius,
            longitudinalMeters: searchRadius
        )
        let request = MKLocalSearch.Request(
            naturalLanguageQuery: category.searchQuery,
            region: region
        )
        request.resultTypes = .pointOfInterest
        request.regionPriority = .required
        if !category.pointOfInterestCategories.isEmpty {
            request.pointOfInterestFilter = MKPointOfInterestFilter(
                including: category.pointOfInterestCategories
            )
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            var seenIdentifiers = Set<String>()
            let places = response.mapItems.compactMap { mapItem -> NearbyPlace? in
                guard let rawName = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawName.isEmpty else {
                    return nil
                }
                let itemLocation = mapItemLocation(for: mapItem)
                let distance = location.distance(from: itemLocation)
                guard distance <= searchRadius * 1.5 else { return nil }

                let identifier = mapItem.identifier?.rawValue
                    ?? "\(rawName)|\(itemLocation.coordinate.latitude)|\(itemLocation.coordinate.longitude)"
                guard seenIdentifiers.insert(identifier).inserted else { return nil }

                return NearbyPlace(
                    id: identifier,
                    name: rawName,
                    address: address(for: mapItem),
                    phoneNumber: mapItem.phoneNumber?.nonEmpty,
                    location: itemLocation,
                    distance: distance,
                    category: category,
                    mapItem: mapItem
                )
            }
            return places.sorted { $0.distance < $1.distance }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NearbyServiceError.searchFailed(error.localizedDescription)
        }
    }

    private func requestWhenInUseAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func mapItemLocation(for mapItem: MKMapItem) -> CLLocation {
        if #available(iOS 26.0, *) {
            return mapItem.location
        } else if let location = mapItem.placemark.location {
            return location
        } else {
            return CLLocation(
                latitude: mapItem.placemark.coordinate.latitude,
                longitude: mapItem.placemark.coordinate.longitude
            )
        }
    }

    private func address(for mapItem: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            return mapItem.address?.fullAddress.nonEmpty
                ?? mapItem.addressRepresentations?
                    .fullAddress(includingRegion: false, singleLine: true)?
                    .nonEmpty
        } else {
            let placemark = mapItem.placemark
            let street = [placemark.subThoroughfare, placemark.thoroughfare]
                .compactMap { $0?.nonEmpty }
                .joined(separator: " ")
            return [street.nonEmpty, placemark.subLocality?.nonEmpty, placemark.locality?.nonEmpty]
                .compactMap { $0 }
                .joined(separator: ", ")
                .nonEmpty
        }
    }
}

extension MapKitNearbyPlacesService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation?.resume(returning: true)
            authorizationContinuation = nil
        case .denied, .restricted:
            authorizationContinuation?.resume(returning: false)
            authorizationContinuation = nil
            locationContinuation?.resume(throwing: NearbyServiceError.permissionDenied)
            locationContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation?.resume(returning: false)
            authorizationContinuation = nil
            locationContinuation?.resume(throwing: NearbyServiceError.permissionDenied)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations
            .filter({ $0.horizontalAccuracy >= 0 })
            .max(by: { $0.timestamp < $1.timestamp }) else {
            locationContinuation?.resume(throwing: NearbyServiceError.locationUnavailable)
            locationContinuation = nil
            return
        }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nearbyError: Error
        if let locationError = error as? CLError, locationError.code == .denied {
            nearbyError = NearbyServiceError.permissionDenied
        } else {
            nearbyError = NearbyServiceError.locationUnavailable
        }
        locationContinuation?.resume(throwing: nearbyError)
        locationContinuation = nil
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
