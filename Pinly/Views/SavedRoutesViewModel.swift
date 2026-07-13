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
            // Önce SwiftData'dan isim ile eşleştirmeyi dene
            let descriptor = FetchDescriptor<Place>(
                predicate: #Predicate { place in place.name == snap.name }
            )
            if let existing = try? context.fetch(descriptor).first {
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

    func delete(_ route: SavedRoute, context: ModelContext) {
        savedRoutes.delete(route, context: context)
    }
}
