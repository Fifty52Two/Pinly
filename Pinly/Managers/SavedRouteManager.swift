import Foundation
import CoreLocation
import SwiftData

// MARK: - SavedRouteRepository

/// Kayıtlı rotaların kalıcılığı ve uzaklık hesabı.
@MainActor
protocol SavedRouteRepository: AnyObject {
    func save(name: String, categoryRaw: String?, places: [Place], context: ModelContext)
    /// Kullanıcının mevcut konumu ile rotanın merkezi arasındaki mesafe (km)
    func distanceKm(from userLocation: CLLocation?, to route: SavedRoute) -> Double?
    func delete(_ route: SavedRoute, context: ModelContext)
}

@MainActor
final class DefaultSavedRouteRepository: SavedRouteRepository {
    static let shared = DefaultSavedRouteRepository()

    // MARK: - Kayıtlı rotayı SwiftData'ya ekle

    func save(
        name: String,
        categoryRaw: String?,
        places: [Place],
        context: ModelContext
    ) {
        guard !places.isEmpty else { return }

        // Rota merkezi: mekanların koordinat ortalaması.
        // Hiç koordinat yoksa (0,0) yerine İstanbul default'una düş —
        // uzaklık uyarısı ve harita thumbnail'i saçmalamasın.
        let coords = places.compactMap { $0.coordinate }
        let centerLat = coords.isEmpty ? 41.015137 : coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let centerLon = coords.isEmpty ? 28.979530 : coords.map(\.longitude).reduce(0, +) / Double(coords.count)

        let snapshots = places.enumerated().map { index, place in
            SavedPlaceSnapshot(
                name: place.name,
                category: place.category,
                address: place.address,
                notes: place.notes,
                latitude: place.coordinate?.latitude ?? centerLat,
                longitude: place.coordinate?.longitude ?? centerLon,
                sortIndex: index
            )
        }

        let route = SavedRoute(
            name: name,
            categoryRaw: categoryRaw,
            centerLatitude: centerLat,
            centerLongitude: centerLon,
            snapshots: snapshots
        )

        context.insert(route)
        try? context.save()
    }

    // MARK: - Uzaklık kontrolü

    func distanceKm(from userLocation: CLLocation?, to route: SavedRoute) -> Double? {
        guard let userLoc = userLocation else { return nil }
        let center = CLLocation(latitude: route.centerLatitude, longitude: route.centerLongitude)
        return userLoc.distance(from: center) / 1000
    }

    // MARK: - Silme

    func delete(_ route: SavedRoute, context: ModelContext) {
        context.delete(route)
        try? context.save()
    }
}
