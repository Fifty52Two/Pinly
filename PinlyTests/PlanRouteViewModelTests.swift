import XCTest
import CoreLocation
import SwiftData
@testable import Pinly

@MainActor
final class PlanRouteViewModelTests: XCTestCase {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Place.self, RouteHistory.self, SavedRoute.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func test_distanceFromPin_calculatesCorrectly() {
        let vm = PlanRouteViewModel()
        vm.pinCoordinate = CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0)

        let nearby = Place(name: "Nearby")
        nearby.latitude = 41.0
        nearby.longitude = 29.0
        XCTAssertEqual(vm.distanceFromPin(to: nearby), "0 m")

        let noPinPlace = Place(name: "NoCoord")
        XCTAssertNil(vm.distanceFromPin(to: noPinPlace))
    }

    func test_sortedPlaces_ordersByDistanceFromPin() {
        let vm = PlanRouteViewModel()
        vm.pinCoordinate = CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0)

        let near = Place(name: "Near")
        near.latitude = 41.001; near.longitude = 29.001
        let far = Place(name: "Far")
        far.latitude = 45.0; far.longitude = 35.0

        let sorted = vm.sortedPlaces([far, near])
        XCTAssertEqual(sorted.map(\.name), ["Near", "Far"])
    }

    func test_selectedPlaces_filtersBySelectedIDs() {
        let vm = PlanRouteViewModel()
        let a = Place(name: "A")
        let b = Place(name: "B")
        vm.selectedPlaceIDs = [a.id]

        let selected = vm.selectedPlaces(from: [a, b])
        XCTAssertEqual(selected.map(\.name), ["A"])
    }

    func test_editingRoute_hydratesInitialState() {
        let snapshot = SavedPlaceSnapshot(name: "Cafe", category: PlaceCategory.cafe.rawValue, address: "", notes: "", latitude: 41.0, longitude: 29.0, sortIndex: 0)
        let route = SavedRoute(name: "My Route", categoryRaw: RouteCategory.city.rawValue, centerLatitude: 41.0, centerLongitude: 29.0, snapshots: [snapshot])

        let existingPlace = Place(name: "Cafe", category: PlaceCategory.cafe.rawValue)

        let vm = PlanRouteViewModel(editingRoute: route)
        let region = vm.hydrateIfEditing(places: [existingPlace])

        XCTAssertNotNil(region)
        XCTAssertEqual(vm.routeName, "My Route")
        XCTAssertEqual(vm.routeCategory, .city)
        XCTAssertEqual(vm.selectedPlaceIDs, [existingPlace.id])
    }

    func test_saveRoute_requiresNameAndSelection() {
        let vm = PlanRouteViewModel(badges: MockBadgeServicing())
        let context = makeInMemoryContext()

        // pin yok, isim yok, seçim yok — kaydetmemeli
        XCTAssertFalse(vm.saveRoute(places: [], context: context))

        vm.pinCoordinate = CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0)
        vm.routeName = "Test Route"
        let place = Place(name: "A")
        place.latitude = 41.0; place.longitude = 29.0
        vm.selectedPlaceIDs = [place.id]

        XCTAssertTrue(vm.saveRoute(places: [place], context: context))
        XCTAssertTrue(vm.savedSuccessfully)
    }
}
