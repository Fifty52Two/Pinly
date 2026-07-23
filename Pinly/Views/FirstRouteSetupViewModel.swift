import Foundation
import CoreLocation
import SwiftData

// MARK: - FirstRouteSuggestion

/// `FirstRouteSetupView`'ın gösterdiği öneri türü.
enum FirstRouteSuggestion: Equatable {
    case cityCatalog(entry: RouteCatalogEntry)
    case nearby([NearbyPlace])
    case none

    static func == (lhs: FirstRouteSuggestion, rhs: FirstRouteSuggestion) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case let (.cityCatalog(a), .cityCatalog(b)): return a.id == b.id
        case let (.nearby(a), .nearby(b)): return a.map(\.id) == b.map(\.id)
        default: return false
        }
    }
}

// MARK: - FirstRouteSetupViewModel
//
// Onboarding sonrası "İlk rotanı 30 saniyede kur" akışının durumu (FAZ 4). Konum İZNİNİ
// KENDİSİ İSTEMEZ — yalnızca izin zaten verilmiş olduğu bilinen bir noktada (HomeView ilk
// açılış) çağrılır; mimari kısıt burada da korunur (bkz. GROWTH_PLAN FAZ 4 notu).
//
// Stateful/oturuma özel bağımlılıklar (ModelContext) constructor'da TUTULMAZ, ilgili
// metotlara parametre geçirilir — projedeki diğer ViewModel'lerle aynı desen.
@MainActor
final class FirstRouteSetupViewModel: ObservableObject {
    @Published private(set) var suggestion: FirstRouteSuggestion = .none
    @Published private(set) var isLoading = true

    private let starterRoutes: StarterRoutesProviding
    private let nearbySearch: NearbySearching
    private let analytics: AnalyticsTracking

    init(
        starterRoutes: StarterRoutesProviding = DefaultStarterRoutesProvider(),
        nearbySearch: NearbySearching = DefaultNearbySearchService.shared,
        analytics: AnalyticsTracking = NoOpAnalyticsService.shared
    ) {
        self.starterRoutes = starterRoutes
        self.nearbySearch = nearbySearch
        self.analytics = analytics
    }

    /// Şehir kataloğunu dener; bulamazsa (ya da koordinat yoksa) `NearbySearching` ile
    /// karışık kategorilerden en yakın 5 öneriyi toplar. Hiçbiri yoksa `.none`.
    func load(cityRaw: String, coordinate: CLLocationCoordinate2D?) async {
        isLoading = true
        defer { isLoading = false }

        if !cityRaw.isEmpty {
            let entries = starterRoutes.loadCityCatalog(city: cityRaw)
            if let best = entries.first {
                suggestion = .cityCatalog(entry: best)
                return
            }
        }

        guard let coordinate else {
            suggestion = .none
            return
        }

        // Paralel arama (RouteManager.calculateRoutes'taki TaskGroup deseniyle aynı) —
        // 4 kategoriyi sırayla değil aynı anda sorgular, "30 saniye" vaadini korur.
        let categories: [PlaceCategory] = [.cafe, .restaurant, .historical, .park]
        let nearbySearch = self.nearbySearch
        let found = await withTaskGroup(of: [NearbyPlace].self) { group in
            for category in categories {
                group.addTask {
                    await nearbySearch.searchNearby(coordinate: coordinate, category: category, radiusMeters: 1500)
                }
            }
            var combined: [NearbyPlace] = []
            for await partial in group {
                combined.append(contentsOf: partial)
            }
            return combined
        }
        let top = Array(found.sorted { $0.distanceMeters < $1.distanceMeters }.prefix(5))
        suggestion = top.isEmpty ? .none : .nearby(top)
    }

    /// Hazır katalog rotasını `SavedRoute`'a çevirip kalıcı hale getirir.
    func adoptCityRoute(_ entry: RouteCatalogEntry, languageCode: String, context: ModelContext) -> SavedRoute {
        let route = starterRoutes.makeSavedRoute(from: entry, languageCode: languageCode)
        context.insert(route)
        try? context.save()
        analytics.track(.starterRouteAdopted(source: entry.id))
        return route
    }

    /// Yakınımda önerilerini (mesafeye göre sıralı) tek bir `SavedRoute`'a çevirip kaydeder.
    func adoptNearbyPlaces(_ places: [NearbyPlace], context: ModelContext) -> SavedRoute {
        let sorted = places.sorted { $0.distanceMeters < $1.distanceMeters }
        let snapshots = sorted.enumerated().map { index, place in
            SavedPlaceSnapshot(
                name: place.name,
                category: place.category.rawValue,
                address: place.address,
                notes: "",
                latitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude,
                sortIndex: index
            )
        }
        let count = Double(max(sorted.count, 1))
        let route = SavedRoute(
            name: NSLocalizedString("İlk Rotam", comment: ""),
            categoryRaw: RouteCategory.city.rawValue,
            centerLatitude: sorted.map { $0.coordinate.latitude }.reduce(0, +) / count,
            centerLongitude: sorted.map { $0.coordinate.longitude }.reduce(0, +) / count,
            snapshots: snapshots
        )
        context.insert(route)
        try? context.save()
        analytics.track(.starterRouteAdopted(source: "nearby_fallback"))
        return route
    }
}
