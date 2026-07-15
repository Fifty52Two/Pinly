import Foundation
import CoreLocation

@MainActor
final class NearbyPlacesViewModel: ObservableObject {
    @Published var results: [NearbyPlace] = []
    @Published var isLoading = false
    @Published var selectedCategory: PlaceCategory = .restaurant
    @Published var errorMessage: String? = nil

    private let nearbySearch: NearbySearching
    private let analytics: AnalyticsTracking

    init(nearbySearch: NearbySearching = DefaultNearbySearchService.shared,
         analytics: AnalyticsTracking = NoOpAnalyticsService.shared) {
        self.nearbySearch = nearbySearch
        self.analytics = analytics
    }

    func search(coordinate: CLLocationCoordinate2D, radiusMeters: Double = 1000) async {
        isLoading = true
        errorMessage = nil
        analytics.track(.nearbySearch(category: selectedCategory.rawValue))
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
