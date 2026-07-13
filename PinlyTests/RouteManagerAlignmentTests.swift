import XCTest
import CoreLocation
@testable import Pinly

@MainActor
final class RouteManagerAlignmentTests: XCTestCase {

    private func makePlaces(_ count: Int) -> [Place] {
        (0..<count).map { i in
            let place = Place(name: "Durak \(i)")
            place.latitude = 41.0 + Double(i) * 0.01
            place.longitude = 29.0 + Double(i) * 0.01
            return place
        }
    }

    func test_setRoute_routePlacesCountMatchesInput() {
        let manager = RouteManager()
        let places = makePlaces(3)

        manager.setRoute(places: places, name: "Test Rotası")

        XCTAssertEqual(manager.routePlaces.count, 3)
    }

    func test_setRoute_preservesOrder() {
        let manager = RouteManager()
        let places = makePlaces(4)

        manager.setRoute(places: places, name: "")

        XCTAssertEqual(manager.routePlaces.map(\.name), places.map(\.name))
    }

    func test_setRoute_setsRouteName() {
        let manager = RouteManager()
        manager.setRoute(places: makePlaces(1), name: "Sahil Turu")

        XCTAssertEqual(manager.routeName, "Sahil Turu")
    }

    func test_reset_clearsAllRouteState() {
        let manager = RouteManager()
        manager.setRoute(places: makePlaces(2), name: "Bir Rota")

        manager.reset()

        XCTAssertTrue(manager.routePlaces.isEmpty)
        XCTAssertEqual(manager.routeName, "")
        XCTAssertFalse(manager.isNavigating)
        XCTAssertFalse(manager.isRouteComplete)
        XCTAssertEqual(manager.currentWaypointIndex, 0)
        XCTAssertEqual(manager.completionPercentage, 0)
    }

    func test_setRoute_calledTwice_secondCallReplacesFirst() {
        let manager = RouteManager()
        manager.setRoute(places: makePlaces(3), name: "İlk Rota")
        manager.setRoute(places: makePlaces(1), name: "İkinci Rota")

        XCTAssertEqual(manager.routePlaces.count, 1)
        XCTAssertEqual(manager.routeName, "İkinci Rota")
    }

    func test_resumeNavigation_atLastStop_completesRoute() {
        let manager = RouteManager()
        let places = makePlaces(2)
        manager.setRoute(places: places, name: "")
        manager.isNavigating = true
        manager.isPausedAtStop = true
        manager.currentWaypointIndex = 0

        manager.resumeNavigation()
        // currentWaypointIndex now 1 (last place, index 1 of 2) — still not complete
        XCTAssertFalse(manager.isRouteComplete)

        manager.isPausedAtStop = true
        manager.resumeNavigation()
        // currentWaypointIndex advances past the last place — route completes
        XCTAssertTrue(manager.isRouteComplete)
        XCTAssertFalse(manager.isNavigating)
        XCTAssertEqual(manager.completionPercentage, 1.0, accuracy: 0.0001)
    }

    func test_resumeNavigation_whenNotPaused_doesNothing() {
        let manager = RouteManager()
        manager.setRoute(places: makePlaces(2), name: "")
        manager.isPausedAtStop = false

        manager.resumeNavigation()

        XCTAssertEqual(manager.currentWaypointIndex, 0)
    }
}
