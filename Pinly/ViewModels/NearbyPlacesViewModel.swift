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

    /// Uçuşta olan arama. Kategori/yarıçap hızlıca değiştirildiğinde önceki arama
    /// İPTAL EDİLİR — aksi halde N eşzamanlı `MKLocalSearch` başlıyor ve EN SON DÖNEN
    /// kazanıyordu, yani seçili kategoriyle alakasız (eski) sonuçlar ekranda kalabiliyordu.
    /// Ayrıca ilk biten `isLoading`'i temizlediği için spinner erken kayboluyor ve geç
    /// gelen boş sonuç, dolu bir listenin önüne "sonuç bulunamadı" hatası yazabiliyordu.
    private var searchTask: Task<Void, Never>?

    init(nearbySearch: NearbySearching = DefaultNearbySearchService.shared,
         analytics: AnalyticsTracking = RuntimeAnalyticsService.shared) {
        self.nearbySearch = nearbySearch
        self.analytics = analytics
    }

    func search(coordinate: CLLocationCoordinate2D, radiusMeters: Double = 1000) async {
        searchTask?.cancel()

        let category = selectedCategory
        let task = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            self.errorMessage = nil
            self.analytics.track(.nearbySearch(category: category.rawValue))

            let found = await self.nearbySearch.searchNearby(
                coordinate: coordinate,
                category: category,
                radiusMeters: radiusMeters
            )

            // İptal edildiysek hiçbir @Published alana DOKUNMA — yerimize geçen
            // yeni arama zaten kendi isLoading/results/errorMessage'ını yönetiyor.
            guard !Task.isCancelled else { return }

            self.results = found
            self.errorMessage = found.isEmpty
                ? NSLocalizedString("Yakında sonuç bulunamadı.", comment: "")
                : nil
            self.isLoading = false
        }
        searchTask = task
        await task.value
    }

    func reset() {
        searchTask?.cancel()
        searchTask = nil
        results = []
        errorMessage = nil
        isLoading = false
    }

    deinit { searchTask?.cancel() }
}
