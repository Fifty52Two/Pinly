import Foundation
import CoreLocation
import SwiftData

// MARK: - SavedRoutesViewModel
//
// SavedRoutesView'ın iş mantığı: uzaklık kontrolü, rota yükleme/başlatma, silme.
// PlacesListViewModel deseninin devamı — stateful/oturuma özel bağımlılıklar
// (RouteManager, ModelContext) constructor'da tutulmaz, ilgili metodlara
// parametre olarak geçirilir.

@MainActor
final class SavedRoutesViewModel: ObservableObject {
    @Published var pendingRoute: SavedRoute? = nil
    @Published var distanceText = ""
    @Published var routeToDelete: SavedRoute? = nil
    @Published var routeToEdit: SavedRoute? = nil

    private let savedRoutes: SavedRouteRepository
    private let badges: BadgeServicing

    init(
        savedRoutes: SavedRouteRepository = DefaultSavedRouteRepository.shared,
        badges: BadgeServicing = DefaultBadgeService.shared
    ) {
        self.savedRoutes = savedRoutes
        self.badges = badges
    }

    func distanceKm(from userLocation: CLLocation?, to route: SavedRoute) -> Double? {
        savedRoutes.distanceKm(from: userLocation, to: route)
    }

    /// Uzaklık 1 km'den fazlaysa true döner ve `pendingRoute`/`distanceText`'i doldurur —
    /// çağıran taraf bu durumda uzaklık uyarı alert'ini göstermeli.
    func handleStartRoute(_ route: SavedRoute, userLocation: CLLocation?) -> Bool {
        guard let dist = savedRoutes.distanceKm(from: userLocation, to: route), dist > 1 else {
            return false
        }
        let formatted = dist >= 10
            ? String(format: "%.0f km", dist)
            : String(format: "%.1f km", dist)
        distanceText = String(
            format: NSLocalizedString(
                "Rotanın başlangıç noktasına yaklaşık %@ uzaktasınız. Yine de başlatmak istiyor musunuz?",
                comment: ""
            ),
            formatted
        )
        pendingRoute = route
        return true
    }

    /// Rota mekanlarını SwiftData'dan (varsa) eşleştirip navigasyon takipçisine yükler.
    func loadAndStart(_ route: SavedRoute, into tracker: RouteNavigationTracking, context: ModelContext) {
        let snapshots = route.placeSnapshots.sorted { $0.sortIndex < $1.sortIndex }

        var places: [Place] = []
        for snap in snapshots {
            // Önce placeId ile eşleştir (kalıcı), yoksa isimle (eski kayıtlar/dış rotalar)
            if let existing = fetchPlace(for: snap, context: context) {
                places.append(existing)
            } else {
                // Geçici yer tutucu — koordinatları ayarla
                let temp = Place(
                    name: snap.name,
                    category: snap.category,
                    address: snap.address,
                    notes: snap.notes
                )
                temp.latitude = snap.latitude
                temp.longitude = snap.longitude
                places.append(temp)
            }
        }

        tracker.setRoute(places: places, name: route.name)
        badges.recordRouteStarted()
    }

    private func fetchPlace(for snap: SavedPlaceSnapshot, context: ModelContext) -> Place? {
        if let placeId = snap.placeId {
            let byId = FetchDescriptor<Place>(
                predicate: #Predicate { place in place.id == placeId }
            )
            if let match = try? context.fetch(byId).first {
                return match
            }
        }
        let snapName = snap.name
        let byName = FetchDescriptor<Place>(
            predicate: #Predicate { place in place.name == snapName }
        )
        return try? context.fetch(byName).first
    }

    func delete(_ route: SavedRoute, context: ModelContext) {
        savedRoutes.delete(route, context: context)
    }
}
