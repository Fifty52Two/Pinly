import Foundation
import MapKit
import CoreLocation
@testable import Pinly

/// Mock RouteManager — RouteNavigationTracking protokolune conform.
/// Hesaplama (RouteCalculating) artik ayri RouteCalculator sinifinda;
/// RouteManager sadece navigasyon state'i yonetiyor.
@MainActor
final class MockRouteManager: RouteNavigationTracking {
    // Route data (RouteManager'da hala @Published olarak var)
    var routePolylines: [MKPolyline] = []
    var stepsPerSegment: [[MKRoute.Step]] = []
    var segmentDistances: [Double] = []
    var totalRouteDistance: Double = 0
    var totalRouteTime: TimeInterval = 0
    var isRecalculating: Bool = false
    var failedLegCount: Int = 0
    var unroutableStopCount: Int = 0
    var calculateRoutesCallCount = 0

    var breadcrumbPolyline: MKPolyline? = nil

    // RouteNavigationTracking
    var selectedCategories: [String] = []
    var selectedPlaces: [String: [Place]] = [:]
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
        routePlacesOverride ?? selectedCategories.flatMap { selectedPlaces[$0] ?? [] }
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

    // Live Activity cagri sayaclari
    var startLiveActivityCallCount = 0
    var updateLiveActivityCallCount = 0
    var endLiveActivityCallCount = 0

    func startLiveActivity() { startLiveActivityCallCount += 1 }
    func updateLiveActivity() { updateLiveActivityCallCount += 1 }
    func endLiveActivity() { endLiveActivityCallCount += 1 }
}
