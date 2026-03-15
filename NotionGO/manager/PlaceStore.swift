import Foundation
import CoreLocation
import MapKit
import SwiftData

@MainActor
class PlaceStore: ObservableObject {
    @Published var places: [Place] = []

    func load(context: ModelContext) {
        let descriptor = FetchDescriptor<Place>()
        places = (try? context.fetch(descriptor)) ?? []
    }

    func addPlace(name: String, category: String, address: String, notes: String, context: ModelContext) async {
        let place = Place(name: name, category: category, address: address, notes: notes)
        
        // Adresten koordinat bul
        if let coord = await resolveCoordinate(name: name, address: address) {
            place.latitude = coord.latitude
            place.longitude = coord.longitude
            place.locationName = address
        }

        context.insert(place)
        try? context.save()
        load(context: context)
    }

    func deletePlace(_ place: Place, context: ModelContext) {
        context.delete(place)
        try? context.save()
        load(context: context)
    }

    private func resolveCoordinate(name: String, address: String) async -> CLLocationCoordinate2D? {
        // 1. Mekan adı + adres ile MKLocalSearch
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = "\(name), \(address)"
        if let item = try? await MKLocalSearch(request: req).start().mapItems.first {
            return item.placemark.coordinate
        }

        // 2. Sadece adres ile
        let req2 = MKLocalSearch.Request()
        req2.naturalLanguageQuery = address
        if let item = try? await MKLocalSearch(request: req2).start().mapItems.first {
            return item.placemark.coordinate
        }

        return nil
    }

    // radiusKm == 0 means unlimited (no distance filter)
    func places(category: String, userLocation: CLLocation?, radiusKm: Double = 5.0) -> [Place] {
        places
            .filter { place in
                let categoryMatch = place.category.lowercased() == category.lowercased()
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
