import Foundation
import CoreLocation
import SwiftData
@testable import Pinly

@MainActor
final class MockPlaceRepository: PlaceRepository {
    var places: [Place] = []
    var lastError: String?
    var pendingBadges: [Badge] = []

    var refreshBadgesCallCount = 0
    var addPlaceCallCount = 0
    var deletePlaceCallCount = 0
    var importPlaceCallCount = 0

    func refreshBadges() {
        refreshBadgesCallCount += 1
    }

    func load(context: ModelContext) {}

    func addPlace(name: String, category: String, address: String, notes: String, coordinate: CLLocationCoordinate2D?, context: ModelContext) async {
        addPlaceCallCount += 1
        let place = Place(name: name, category: category, address: address, notes: notes)
        if let coordinate {
            place.latitude = coordinate.latitude
            place.longitude = coordinate.longitude
        }
        places.append(place)
    }

    func deletePlace(_ place: Place, context: ModelContext) {
        deletePlaceCallCount += 1
        places.removeAll { $0.id == place.id }
    }

    func save(context: ModelContext) {}

    func places(category: String, userLocation: CLLocation?, radiusKm: Double) -> [Place] {
        places.filter { PlaceCategory.from($0.category) == PlaceCategory.from(category) }
    }

    var allCategories: [String] {
        Array(Set(places.map { $0.category })).sorted()
    }

    func importPlace(_ data: PlaceImportData, context: ModelContext) async {
        importPlaceCallCount += 1
        places.append(Place(name: data.name, category: data.category, address: data.address, notes: data.notes))
    }
}
