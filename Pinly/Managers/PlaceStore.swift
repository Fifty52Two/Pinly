import Foundation
import CoreLocation
import MapKit
import SwiftData

// MARK: - PlaceRepository

/// Mekan kalıcılığı, sorgulama ve içe aktarma sorumluluğunun tek kaynağı.
@MainActor
protocol PlaceRepository: AnyObject {
    var places: [Place] { get }
    var lastError: String? { get set }
    var pendingBadges: [Badge] { get set }
    func refreshBadges()
    func load(context: ModelContext)
    func addPlace(name: String, category: String, address: String, notes: String, coordinate: CLLocationCoordinate2D?, context: ModelContext) async
    func deletePlace(_ place: Place, context: ModelContext)
    func save(context: ModelContext)
    func places(category: String, userLocation: CLLocation?, radiusKm: Double) -> [Place]
    var allCategories: [String] { get }
    /// Deep-link / QR / Swarm içe aktarımından gelen tek bir mekanı kaydeder.
    func importPlace(_ data: PlaceImportData, context: ModelContext) async
}

@MainActor
class PlaceStore: PlaceRepository, ObservableObject {
    @Published var places: [Place] = []
    @Published var lastError: String? = nil
    @Published var pendingBadges: [Badge] = []

    private let badges: BadgeServicing
    private let geocoding: GeocodingProviding

    init(badges: BadgeServicing = DefaultBadgeService.shared,
         geocoding: GeocodingProviding = DefaultGeocodingService.shared) {
        self.badges = badges
        self.geocoding = geocoding
    }

    /// Rozet kontrolü yapar; yeni açılan rozetleri banner kuyruğuna ekler.
    func refreshBadges() {
        let newBadges = badges.check(placeStore: self)
        pendingBadges.append(contentsOf: newBadges)
    }

    func load(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Place>()
            places = try context.fetch(descriptor)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addPlace(name: String, category: String, address: String, notes: String, coordinate: CLLocationCoordinate2D? = nil, context: ModelContext) async {
        let place = Place(name: name, category: category, address: address, notes: notes)

        if let coord = coordinate {
            // Haritadan pinlenen koordinat — geocode atlanır
            place.latitude = coord.latitude
            place.longitude = coord.longitude
            place.locationName = address
        } else if let coord = await resolveCoordinate(name: name, address: address) {
            place.latitude = coord.latitude
            place.longitude = coord.longitude
            place.locationName = address
        }

        context.insert(place)
        save(context: context)
        load(context: context)
        refreshBadges()
    }

    func deletePlace(_ place: Place, context: ModelContext) {
        context.delete(place)
        save(context: context)
        load(context: context)
    }

    func save(context: ModelContext) {
        do {
            try context.save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func resolveCoordinate(name: String, address: String) async -> CLLocationCoordinate2D? {
        if let coord = await geocoding.forwardGeocode(query: "\(name), \(address)") {
            return coord
        }
        return await geocoding.forwardGeocode(query: address)
    }

    /// Deep-link / QR / Swarm içe aktarımından gelen tek bir mekanı kaydeder.
    /// Koordinat zaten mevcutsa geocode atlanır, yoksa `addPlace` üzerinden çözümlenir.
    func importPlace(_ data: PlaceImportData, context: ModelContext) async {
        if let lat = data.latitude, let lon = data.longitude {
            let place = Place(name: data.name, category: data.category, address: data.address, notes: data.notes)
            place.latitude = lat
            place.longitude = lon
            place.locationName = data.address
            context.insert(place)
            save(context: context)
            load(context: context)
            refreshBadges()
        } else {
            await addPlace(
                name: data.name,
                category: data.category,
                address: data.address,
                notes: data.notes,
                context: context
            )
        }
    }

    // radiusKm == 0 means unlimited (no distance filter)
    func places(category: String, userLocation: CLLocation?, radiusKm: Double = 5.0) -> [Place] {
        let targetCategory = PlaceCategory.from(category)
        return places
            .filter { place in
                let categoryMatch = PlaceCategory.from(place.category) == targetCategory
                guard categoryMatch else { return false }
                guard radiusKm > 0, let coord = place.coordinate, let userLoc = userLocation else {
                    return categoryMatch
                }
                let placeLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                return userLoc.distance(from: placeLoc) / 1000 <= radiusKm
            }
            .sorted { a, b in
                guard let coordA = a.coordinate, let coordB = b.coordinate,
                      let userLoc = userLocation else { return false }
                let locA = CLLocation(latitude: coordA.latitude, longitude: coordA.longitude)
                let locB = CLLocation(latitude: coordB.latitude, longitude: coordB.longitude)
                return userLoc.distance(from: locA) < userLoc.distance(from: locB)
            }
    }

    var allCategories: [String] {
        Array(Set(places.map { $0.category })).sorted()
    }
}
