import XCTest
@testable import Pinly

final class StarterRoutesProviderTests: XCTestCase {
    private let provider = DefaultStarterRoutesProvider()

    func test_loadAll_ucRotaDondurur() {
        let routes = provider.loadAll()
        XCTAssertEqual(routes.count, 3)
        for route in routes {
            XCTAssertGreaterThanOrEqual(route.places.count, 3)
            XCTAssertFalse(route.name.isEmpty)
        }
    }

    func test_loadAll_koordinatlarIstanbulSinirlarinda() {
        for route in provider.loadAll() {
            for place in route.places {
                XCTAssertTrue((40.8...41.3).contains(place.latitude), place.name)
                XCTAssertTrue((28.5...29.3).contains(place.longitude), place.name)
            }
        }
    }

    func test_makeSavedRoute_snapshotVeMerkezDogru() {
        guard let def = provider.loadAll().first else {
            return XCTFail("Hazır rota yüklenemedi")
        }
        let saved = provider.makeSavedRoute(from: def)
        XCTAssertEqual(saved.name, def.name)
        XCTAssertEqual(saved.placeSnapshots.count, def.places.count)
        XCTAssertEqual(saved.placeSnapshots.map(\.sortIndex), Array(0..<def.places.count))
        let expectedLat = def.places.map(\.latitude).reduce(0, +) / Double(def.places.count)
        XCTAssertEqual(saved.centerLatitude, expectedLat, accuracy: 0.0001)
    }
}
