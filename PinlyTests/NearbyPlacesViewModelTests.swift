import XCTest
import CoreLocation
@testable import Pinly

// MARK: - Mock

final class MockNearbySearchService: NearbySearching {
    var stubbedResults: [NearbyPlace] = []

    func searchNearby(
        coordinate: CLLocationCoordinate2D,
        category: PlaceCategory,
        radiusMeters: Double
    ) async -> [NearbyPlace] {
        stubbedResults
    }
}

// MARK: - Tests

@MainActor
final class NearbyPlacesViewModelTests: XCTestCase {

    private let coord = CLLocationCoordinate2D(latitude: 41.0, longitude: 28.0)

    func test_search_sonuclarGelince_resultsGüncellenir() async {
        let mock = MockNearbySearchService()
        mock.stubbedResults = [
            NearbyPlace(
                name: "Test Kafe",
                address: "Test Sokak",
                coordinate: coord,
                category: .cafe,
                distanceMeters: 120
            )
        ]
        let vm = NearbyPlacesViewModel(nearbySearch: mock)
        await vm.search(coordinate: coord)
        XCTAssertEqual(vm.results.count, 1)
        XCTAssertEqual(vm.results.first?.name, "Test Kafe")
        XCTAssertNil(vm.errorMessage)
    }

    func test_search_bossonsucta_hataGosterilir() async {
        let mock = MockNearbySearchService()
        mock.stubbedResults = []
        let vm = NearbyPlacesViewModel(nearbySearch: mock)
        await vm.search(coordinate: coord)
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_reset_stateTemizlenir() async {
        let mock = MockNearbySearchService()
        mock.stubbedResults = [
            NearbyPlace(name: "A", address: "", coordinate: coord, category: .park, distanceMeters: 40)
        ]
        let vm = NearbyPlacesViewModel(nearbySearch: mock)
        await vm.search(coordinate: coord)
        XCTAssertEqual(vm.results.count, 1)
        vm.reset()
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertNil(vm.errorMessage)
    }
}
