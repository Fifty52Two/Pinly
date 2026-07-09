import Foundation
import MapKit
import CoreLocation
import SwiftData

// MARK: - PlanRouteViewModel
//
// PlanRouteView'ın iş mantığı: pin'e göre mesafe sıralaması, mekan seçimi,
// edit-modu hydration, rota kaydetme. `editingRoute` View'ın kendi init'inden
// (çağıran taraftan doğrudan) geldiği için — environment'a bağımlı değil —
// @StateObject'e constructor injection ile güvenle verilebilir.

@MainActor
final class PlanRouteViewModel: ObservableObject {
    let editingRoute: SavedRoute?

    @Published var pinCoordinate: CLLocationCoordinate2D?
    @Published var selectedPlaceIDs: Set<UUID> = []
    @Published var routeName: String = ""
    @Published var routeCategory: RouteCategory = .city
    @Published var isSaving = false
    @Published var savedSuccessfully = false

    private let badges: BadgeServicing

    init(editingRoute: SavedRoute? = nil, badges: BadgeServicing = DefaultBadgeService.shared) {
        self.editingRoute = editingRoute
        self.badges = badges
    }

    /// Mekanları pin'e mesafeye göre sıralar
    func sortedPlaces(_ places: [Place]) -> [Place] {
        guard let pin = pinCoordinate else { return places }
        let pinLoc = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        return places.sorted { a, b in
            let distA = a.coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: pinLoc) } ?? Double.infinity
            let distB = b.coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: pinLoc) } ?? Double.infinity
            return distA < distB
        }
    }

    func selectedPlaces(from places: [Place]) -> [Place] {
        sortedPlaces(places).filter { selectedPlaceIDs.contains($0.id) }
    }

    func distanceFromPin(to place: Place) -> String? {
        guard let pin = pinCoordinate, let coord = place.coordinate else { return nil }
        let dist = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        return dist < 1000
            ? String(format: "%.0f m", dist)
            : String(format: "%.1f km", dist / 1000)
    }

    /// Edit modunda mevcut rota verilerini forma doldurur ve seçili mekanları eşleştirir.
    /// Başlangıç kamerasının ayarlanması gereken bölgeyi döner (edit modu değilse nil).
    func hydrateIfEditing(places: [Place]) -> MKCoordinateRegion? {
        guard let route = editingRoute else { return nil }
        let center = CLLocationCoordinate2D(latitude: route.centerLatitude, longitude: route.centerLongitude)
        pinCoordinate = center
        routeName = route.name
        if let catRaw = route.categoryRaw, let cat = RouteCategory(rawValue: catRaw) {
            routeCategory = cat
        }
        let snapNames = Set(route.placeSnapshots.map { $0.name })
        let matched = places.filter { snapNames.contains($0.name) }
        selectedPlaceIDs = Set(matched.map { $0.id })
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
    }

    @discardableResult
    func saveRoute(places: [Place], context: ModelContext) -> Bool {
        let name = routeName.trimmingCharacters(in: .whitespaces)
        let selected = selectedPlaces(from: places)
        guard !name.isEmpty, !selected.isEmpty, let pin = pinCoordinate else { return false }
        isSaving = true

        let snapshots = selected.enumerated().map { index, place in
            SavedPlaceSnapshot(
                name: place.name,
                category: place.category,
                address: place.address,
                notes: place.notes,
                latitude: place.coordinate?.latitude ?? pin.latitude,
                longitude: place.coordinate?.longitude ?? pin.longitude,
                sortIndex: index
            )
        }

        if let existing = editingRoute {
            // Edit modu: mevcut rotayı güncelle
            existing.name = name
            existing.categoryRaw = routeCategory.rawValue
            existing.centerLatitude = pin.latitude
            existing.centerLongitude = pin.longitude
            existing.orderedPlaceSnapshotsData = (try? JSONEncoder().encode(snapshots)) ?? Data()
        } else {
            // Yeni rota oluştur
            let route = SavedRoute(
                name: name,
                categoryRaw: routeCategory.rawValue,
                centerLatitude: pin.latitude,
                centerLongitude: pin.longitude,
                snapshots: snapshots
            )
            context.insert(route)
            badges.recordSavedRoute()
        }
        try? context.save()

        isSaving = false
        savedSuccessfully = true
        return true
    }
}
