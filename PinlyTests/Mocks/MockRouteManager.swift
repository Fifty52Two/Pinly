import Foundation
import MapKit
import CoreLocation
@testable import Pinly

/// Gerçek `RouteManager`'ın 2 protokole (RouteCalculating/RouteNavigationTracking)
/// tek sınıf olarak conform olma desenini tekrar eder. Live Activity yönetimi
/// RouteLiveActivityController'a ayrıldığı için RouteManager (ve bu mock) artık
/// RouteLiveActivityPresenting'e conform olmuyor — startLiveActivity() vb.
/// çağrı sayaçları düz metod olarak kalıyor.
@MainActor
final class MockRouteManager: RouteCalculating, RouteNavigationTracking {
    // RouteCalculating
    var routePolylines: [MKPolyline] = []
    var stepsPerSegment: [[MKRoute.Step]] = []
    var segmentDistances: [Double] = []
    var totalRouteDistance: Double = 0
    var totalRouteTime: TimeInterval = 0
    var isRecalculating: Bool = false
    var calculateRoutesCallCount = 0

    func calculateRoutes(from userLocation: CLLocationCoordinate2D?, completion: @escaping () -> Void) {
        calculateRoutesCallCount += 1
        completion()
    }

    func recalculateCurrentSegment(from userLocation: CLLocation) { }

    // RouteNavigationTracking
    var selectedCategories: [String] = []
    var selectedPlaces: [String: Place] = [:]
    var routeName: String = ""
    var isNavigating: Bool = false
    var isPausedAtStop: Bool = false
    var currentWaypointIndex: Int = 0
    var currentInstruction: String = ""
    var remainingDistance: String = ""
    var arrivedAtPlace: Place?
    var isRouteComplete: Bool = false
    var completionPercentage: Double = 0
    var routePlacesOverride: [Place]?

    var routePlaces: [Place] {
        routePlacesOverride ?? selectedCategories.compactMap { selectedPlaces[$0] }
    }

    var nextWaypointCoordinate: CLLocationCoordinate2D? {
        guard currentWaypointIndex < routePlaces.count else { return nil }
        return routePlaces[currentWaypointIndex].coordinate
    }

    func setRoute(places: [Place], name: String) {
        routePlacesOverride = places
        routeName = name
    }

    func reset() {
        routePlacesOverride = nil
        selectedCategories = []
        selectedPlaces = [:]
        routeName = ""
        isNavigating = false
    }

    func updateNavigation(userLocation: CLLocation) { }
    func resumeNavigation() { }

    // Live Activity çağrı sayaçları (RouteManager'daki forwarding metodların taklidi)
    var startLiveActivityCallCount = 0
    var updateLiveActivityCallCount = 0
    var endLiveActivityCallCount = 0

    func startLiveActivity() { startLiveActivityCallCount += 1 }
    func updateLiveActivity() { updateLiveActivityCallCount += 1 }
    func endLiveActivity() { endLiveActivityCallCount += 1 }
}
