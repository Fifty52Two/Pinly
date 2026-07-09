import XCTest
import CoreLocation
import SwiftData
@testable import Pinly

@MainActor
final class AddPlaceViewModelTests: XCTestCase {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Place.self, RouteHistory.self, SavedRoute.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func test_fetchCurrentLocation_setsCurrentCoord_fromMockLocationProvider() {
        let vm = AddPlaceViewModel()
        let location = MockLocationProviding()
        location.userLocation = CLLocation(latitude: 41.0, longitude: 29.0)

        vm.fetchCurrentLocation(from: location)

        XCTAssertTrue(vm.usedCurrentLocation)
        XCTAssertEqual(vm.currentCoord?.latitude, 41.0)
        XCTAssertEqual(location.requestLocationCallCount, 0)
    }

    func test_fetchCurrentLocation_requestsLocation_whenNotYetAvailable() {
        let vm = AddPlaceViewModel()
        let location = MockLocationProviding()
        location.userLocation = nil

        vm.fetchCurrentLocation(from: location)

        XCTAssertFalse(vm.usedCurrentLocation)
        XCTAssertEqual(location.requestLocationCallCount, 1)
    }

    func test_save_withCurrentLocation_insertsPlaceDirectly() async {
        let vm = AddPlaceViewModel()
        vm.name = "Test Place"
        vm.category = PlaceCategory.cafe.rawValue
        vm.usedCurrentLocation = true
        vm.currentCoord = CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0)

        let repository = MockPlaceRepository()
        let context = makeInMemoryContext()

        await vm.save(placeStore: repository, context: context)

        // Mevcut konum yolu doğrudan ModelContext.insert kullanır (repository'nin
        // in-memory listesini değil) — bu yüzden context üzerinden doğrulanır.
        let inserted = try? context.fetch(FetchDescriptor<Place>())
        XCTAssertEqual(inserted?.count, 1)
        XCTAssertEqual(inserted?.first?.name, "Test Place")
        XCTAssertFalse(vm.isSaving)
    }

    func test_save_withoutCurrentLocation_delegatesToAddPlace() async {
        let vm = AddPlaceViewModel()
        vm.name = "Geocoded Place"
        vm.category = PlaceCategory.restaurant.rawValue
        vm.address = "Kadıköy"

        let repository = MockPlaceRepository()
        let context = makeInMemoryContext()

        await vm.save(placeStore: repository, context: context)

        XCTAssertEqual(repository.addPlaceCallCount, 1)
    }
}
