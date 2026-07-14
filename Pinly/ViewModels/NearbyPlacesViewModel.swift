import Foundation
import CoreLocation

@MainActor
final class NearbyPlacesViewModel: ObservableObject {
    @Published var results: [NearbyPlace] = []
    @Published var isLoading = false
    @Published var selectedCategory: PlaceCategory = .restaurant
    @Published var errorMessage: String? = nil

    private let nearbySearch: NearbySearching

    init(nearbySearch: NearbySearching = DefaultNearbySearchService.shared) {
        self.nearbySearch = nearbySearch
    }

    func search(coordinate: CLLocationCoordinate2D, radiusMeters: Double = 1000) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let found = await nearbySearch.searchNearby(
            coordinate: coordinate,
            category: selectedCategory,
            radiusMeters: radiusMeters
        )
        if found.isEmpty {
            errorMessage = NSLocalizedString("Yakında sonuç bulunamadı.", comment: "")
        }
        results = found
    }

    func reset() {
        results = []
        errorMessage = nil
    }
}
