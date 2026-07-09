import Foundation
import CoreLocation
import SwiftData
@testable import Pinly

@MainActor
final class MockSavedRouteRepository: SavedRouteRepository {
    var saveCallCount = 0
    var deleteCallCount = 0
    var distanceKmResult: Double?

    func save(name: String, categoryRaw: String?, places: [Place], context: ModelContext) {
        saveCallCount += 1
    }

    func distanceKm(from userLocation: CLLocation?, to route: SavedRoute) -> Double? {
        distanceKmResult
    }

    func delete(_ route: SavedRoute, context: ModelContext) {
        deleteCallCount += 1
    }
}
