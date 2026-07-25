//
//  Created by Doğa Erdemir on 24.07.2026.
//

import CoreLocation
import Foundation

@MainActor
final class NearbyViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failure
    }

    struct State {
        var selectedCategory: NearbyCategory = .fuel
        var places: [NearbyPlace] = []
        var userLocation: CLLocation?
        var phase: Phase = .idle
        var message: String?
        var requiresSettings = false
    }

    private let service: NearbyPlacesService
    private(set) var state = State()
    var onChange: ((State) -> Void)?

    init(service: NearbyPlacesService) {
        self.service = service
    }

    func requestNearbyPlaces() async {
        guard state.phase != .loading else { return }
        publishLoading()

        do {
            let location = try await service.requestCurrentLocation()
            state.userLocation = location
            onChange?(state)
            await searchSelectedCategory(around: location)
        } catch {
            publish(error)
        }
    }

    func refresh() async {
        await requestNearbyPlaces()
    }

    func select(_ category: NearbyCategory) async {
        guard category != state.selectedCategory else { return }
        state.selectedCategory = category
        state.places = []
        state.message = nil
        state.requiresSettings = false

        guard let location = state.userLocation else {
            state.phase = .idle
            onChange?(state)
            return
        }

        publishLoading()
        await searchSelectedCategory(around: location)
    }

    private func searchSelectedCategory(around location: CLLocation) async {
        do {
            let places = try await service.search(category: state.selectedCategory, around: location)
            state.places = places
            state.phase = places.isEmpty ? .empty : .loaded
            state.message = places.isEmpty
                ? "Bu bölgede \(state.selectedCategory.title.lowercased(with: Locale(identifier: "tr_TR"))) sonucu bulunamadı."
                : nil
            state.requiresSettings = false
            onChange?(state)
        } catch {
            publish(error)
        }
    }

    private func publishLoading() {
        state.phase = .loading
        state.places = []
        state.message = nil
        state.requiresSettings = false
        onChange?(state)
    }

    private func publish(_ error: Error) {
        state.phase = .failure
        state.places = []
        state.message = error.localizedDescription
        state.requiresSettings = (error as? NearbyServiceError)?.requiresSettings ?? false
        onChange?(state)
    }
}
