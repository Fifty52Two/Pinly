import XCTest
import SwiftData
@testable import Pinly

@MainActor
final class SavedRoutesViewModelTests: XCTestCase {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Place.self, RouteHistory.self, SavedRoute.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// FAZ 5.2: snapshot'ta placeId varsa, isim değişmiş olsa bile ID ile eşleşmeli.
    func test_loadAndStart_matchesByPlaceId_evenWhenNameChanged() {
        let context = makeInMemoryContext()
        let place = Place(name: "Yeni İsim", category: PlaceCategory.cafe.rawValue)
        place.latitude = 41.0; place.longitude = 29.0
        context.insert(place)

        let snapshot = SavedPlaceSnapshot(
            name: "Eski İsim", category: PlaceCategory.cafe.rawValue, address: "", notes: "",
            latitude: 41.0, longitude: 29.0, sortIndex: 0, placeId: place.id
        )
        let route = SavedRoute(name: "Rota", centerLatitude: 41.0, centerLongitude: 29.0, snapshots: [snapshot])

        let tracker = MockRouteManager()
        let badges = MockBadgeServicing()
        let analytics = MockAnalyticsTracking()
        let vm = SavedRoutesViewModel(badges: badges, analytics: analytics)

        vm.loadAndStart(route, into: tracker, context: context)

        XCTAssertEqual(tracker.routePlaces.count, 1)
        XCTAssertEqual(tracker.routePlaces.first?.id, place.id)
        XCTAssertEqual(tracker.routePlaces.first?.name, "Yeni İsim")
    }

    /// placeId nil ise (eski kayıt/dış rota) isimle eşleşmeye düşülmeli.
    func test_loadAndStart_fallsBackToNameMatch_whenPlaceIdNil() {
        let context = makeInMemoryContext()
        let place = Place(name: "Kadıköy Kahve", category: PlaceCategory.cafe.rawValue)
        place.latitude = 40.9; place.longitude = 29.0
        context.insert(place)

        let snapshot = SavedPlaceSnapshot(
            name: "Kadıköy Kahve", category: PlaceCategory.cafe.rawValue, address: "", notes: "",
            latitude: 40.9, longitude: 29.0, sortIndex: 0
        )
        let route = SavedRoute(name: "Rota", centerLatitude: 40.9, centerLongitude: 29.0, snapshots: [snapshot])

        let tracker = MockRouteManager()
        let vm = SavedRoutesViewModel(badges: MockBadgeServicing(), analytics: MockAnalyticsTracking())

        vm.loadAndStart(route, into: tracker, context: context)

        XCTAssertEqual(tracker.routePlaces.first?.id, place.id)
    }

    /// Ne ID ne isim eşleşmiyorsa (mekan silinmiş) geçici koordinatlı yer tutucu oluşturulmalı.
    func test_loadAndStart_createsPlaceholder_whenNoMatchFound() {
        let context = makeInMemoryContext()

        let snapshot = SavedPlaceSnapshot(
            name: "Silinmiş Mekan", category: PlaceCategory.museum.rawValue, address: "Adres", notes: "",
            latitude: 39.0, longitude: 27.0, sortIndex: 0, placeId: UUID()
        )
        let route = SavedRoute(name: "Rota", centerLatitude: 39.0, centerLongitude: 27.0, snapshots: [snapshot])

        let tracker = MockRouteManager()
        let vm = SavedRoutesViewModel(badges: MockBadgeServicing(), analytics: MockAnalyticsTracking())

        vm.loadAndStart(route, into: tracker, context: context)

        XCTAssertEqual(tracker.routePlaces.count, 1)
        XCTAssertEqual(tracker.routePlaces.first?.name, "Silinmiş Mekan")
        XCTAssertEqual(tracker.routePlaces.first?.latitude, 39.0)
    }

    func test_loadAndStart_ordersPlacesBySortIndex() {
        let context = makeInMemoryContext()
        let a = Place(name: "A"); a.latitude = 1; a.longitude = 1
        let b = Place(name: "B"); b.latitude = 2; b.longitude = 2
        context.insert(a); context.insert(b)

        let snapA = SavedPlaceSnapshot(name: "A", category: PlaceCategory.general.rawValue, address: "", notes: "", latitude: 1, longitude: 1, sortIndex: 1, placeId: a.id)
        let snapB = SavedPlaceSnapshot(name: "B", category: PlaceCategory.general.rawValue, address: "", notes: "", latitude: 2, longitude: 2, sortIndex: 0, placeId: b.id)
        let route = SavedRoute(name: "Rota", centerLatitude: 1, centerLongitude: 1, snapshots: [snapA, snapB])

        let tracker = MockRouteManager()
        let vm = SavedRoutesViewModel(badges: MockBadgeServicing(), analytics: MockAnalyticsTracking())

        vm.loadAndStart(route, into: tracker, context: context)

        XCTAssertEqual(tracker.routePlaces.map(\.name), ["B", "A"])
    }

    func test_loadAndStart_recordsBadgeAndAnalytics() {
        let context = makeInMemoryContext()
        let snapshot = SavedPlaceSnapshot(name: "X", category: PlaceCategory.general.rawValue, address: "", notes: "", latitude: 0, longitude: 0, sortIndex: 0)
        let route = SavedRoute(name: "Rota", centerLatitude: 0, centerLongitude: 0, snapshots: [snapshot])

        let analytics = MockAnalyticsTracking()
        let vm = SavedRoutesViewModel(badges: MockBadgeServicing(), analytics: analytics)

        vm.loadAndStart(route, into: MockRouteManager(), context: context)

        XCTAssertEqual(analytics.trackedEvents, [.routeStarted])
    }

    func test_handleStartRoute_returnsFalse_whenWithinOneKm() {
        let repo = MockSavedRouteRepository()
        repo.distanceKmResult = 0.5
        let vm = SavedRoutesViewModel(savedRoutes: repo, badges: MockBadgeServicing(), analytics: MockAnalyticsTracking())
        let route = SavedRoute(name: "Rota", centerLatitude: 0, centerLongitude: 0, snapshots: [])

        XCTAssertFalse(vm.handleStartRoute(route, userLocation: nil))
    }

    func test_handleStartRoute_returnsTrue_whenBeyondOneKm() {
        let repo = MockSavedRouteRepository()
        repo.distanceKmResult = 5.0
        let vm = SavedRoutesViewModel(savedRoutes: repo, badges: MockBadgeServicing(), analytics: MockAnalyticsTracking())
        let route = SavedRoute(name: "Rota", centerLatitude: 0, centerLongitude: 0, snapshots: [])

        XCTAssertTrue(vm.handleStartRoute(route, userLocation: nil))
        XCTAssertEqual(vm.pendingRoute, route)
    }
}
