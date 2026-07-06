import Foundation
import CoreLocation
import MapKit
import SwiftData

@MainActor
class PlaceStore: ObservableObject {
    @Published var places: [Place] = []
    @Published var lastError: String? = nil
    @Published var pendingBadges: [Badge] = []

    private let badges: BadgeServicing

    init(badges: BadgeServicing = DefaultBadgeService.shared) {
        self.badges = badges
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
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = "\(name), \(address)"
        if let item = try? await MKLocalSearch(request: req).start().mapItems.first {
            return item.placemark.coordinate
        }

        let req2 = MKLocalSearch.Request()
        req2.naturalLanguageQuery = address
        if let item = try? await MKLocalSearch(request: req2).start().mapItems.first {
            return item.placemark.coordinate
        }

        return nil
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
