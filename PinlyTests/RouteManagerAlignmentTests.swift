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

    // MARK: - commitCategorySelection (kategori seçim akışı)

    func test_commitCategorySelection_preservesSelectedCategoriesOrder() {
        let manager = RouteManager()
        let cafe = Place(name: "Kahve Durağı")
        let museum = Place(name: "Müze Durağı")
        let park = Place(name: "Park Durağı")

        manager.selectedCategories = ["Café", "Museum", "Park"]
        manager.selectedPlaces = ["Museum": [museum], "Café": [cafe], "Park": [park]]

        manager.commitCategorySelection()

        XCTAssertEqual(manager.routePlaces.map(\.name), ["Kahve Durağı", "Müze Durağı", "Park Durağı"])
    }

    func test_commitCategorySelection_multiplePlacesPerCategory_preservesSelectionOrder() {
        let manager = RouteManager()
        let cafe1 = Place(name: "Kronotrop")
        let cafe2 = Place(name: "Coffee Sapiens")
        let museum = Place(name: "Pera Müzesi")

        manager.selectedCategories = ["Café", "Museum"]
        manager.selectedPlaces = ["Café": [cafe1, cafe2], "Museum": [museum]]

        manager.commitCategorySelection()

        XCTAssertEqual(manager.routePlaces.map(\.name), ["Kronotrop", "Coffee Sapiens", "Pera Müzesi"])
    }

    func test_commitCategorySelection_categoryWithoutSelection_isDropped() {
        let manager = RouteManager()
        let cafe = Place(name: "Kahve Durağı")

        manager.selectedCategories = ["Café", "Museum"]
        manager.selectedPlaces = ["Café": [cafe]]   // "Museum" için henüz seçim yok

        manager.commitCategorySelection()

        XCTAssertEqual(manager.routePlaces.map(\.name), ["Kahve Durağı"])
    }

    // MARK: - unroutableStopCount (koordinatsız durak uyarısı)
    // Sayaç calculateRoutes'ta guard'dan ÖNCE senkron set edilir — ağ beklemeden assert edilebilir.

    /// Regresyon: konum yokken hesaplanan, TÜM durakları koordinatlı rotada
    /// "Bazı durakların konumu yok" uyarısı ÇIKMAMALI (plan[0]'ın nil olması
    /// bilinmeyen başlangıç demektir, koordinatsız durak değil).
    func test_calculateRoutes_nilUserLocation_allStopsLocated_unroutableCountIsZero() {
        let manager = RouteManager()
        manager.setRoute(places: makePlaces(3), name: "")

        manager.calculateRoutes(from: nil) { }

        XCTAssertEqual(manager.unroutableStopCount, 0)
    }

    func test_calculateRoutes_allStopsUnlocated_setsUnroutableCount_andCompletes() {
        let manager = RouteManager()
        let unlocated = [Place(name: "A"), Place(name: "B")]
        manager.setRoute(places: unlocated, name: "")

        var completed = false
        manager.calculateRoutes(from: nil) { completed = true }

        // Hiç planlanabilir bacak yok → erken çıkış; sayaç yine de set edilmeli
        XCTAssertTrue(completed)
        XCTAssertEqual(manager.unroutableStopCount, 2)
    }

    func test_calculateRoutes_mixedStops_countsOnlyUnlocatedOnes() {
        let manager = RouteManager()
        let located = makePlaces(2)
        let mixed = [located[0], Place(name: "Koordinatsız"), located[1]]
        manager.setRoute(places: mixed, name: "")

        manager.calculateRoutes(from: nil) { }

        XCTAssertEqual(manager.unroutableStopCount, 1)
    }
}
