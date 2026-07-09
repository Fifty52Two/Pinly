import XCTest
import CoreLocation
import SwiftData
@testable import Pinly

@MainActor
final class EditPlaceViewModelTests: XCTestCase {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Place.self, RouteHistory.self, SavedRoute.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func test_init_hydratesFromExistingPlace() {
        let place = Place(name: "Original", category: PlaceCategory.museum.rawValue, address: "Old Address", notes: "note")
        let vm = EditPlaceViewModel(place: place)

        XCTAssertEqual(vm.name, "Original")
        XCTAssertEqual(vm.category, PlaceCategory.museum.rawValue)
        XCTAssertEqual(vm.address, "Old Address")
        XCTAssertEqual(vm.notes, "note")
    }

    func test_save_withPinnedCoordinate_updatesPlaceDirectly() async {
        let place = Place(name: "Original", category: PlaceCategory.cafe.rawValue, address: "Old")
        let vm = EditPlaceViewModel(place: place)
        vm.name = "Updated"
        vm.pinnedCoord = CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0)
        vm.address = "New Address"

        let repository = MockPlaceRepository()
        let context = makeInMemoryContext()

        await vm.save(placeStore: repository, context: context)

        XCTAssertEqual(place.name, "Updated")
        XCTAssertEqual(place.latitude, 41.0)
        XCTAssertEqual(place.address, "New Address")
        XCTAssertFalse(vm.isSaving)
    }

    func test_save_withCurrentLocation_setsMevcutKonum() async {
        let place = Place(name: "Original", category: PlaceCategory.cafe.rawValue, address: "Old")
        let vm = EditPlaceViewModel(place: place)
        vm.usedCurrentLocation = true
        vm.currentCoord = CLLocationCoordinate2D(latitude: 42.0, longitude: 30.0)

        let repository = MockPlaceRepository()
        let context = makeInMemoryContext()

        await vm.save(placeStore: repository, context: context)

        XCTAssertEqual(place.latitude, 42.0)
        XCTAssertEqual(place.address, "Mevcut Konum")
    }
}
