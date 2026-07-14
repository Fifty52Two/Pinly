import XCTest
import CoreLocation
@testable import Pinly

final class RouteOrderOptimizerTests: XCTestCase {

    // MARK: - Yardımcılar

    private func makePlace(name: String, lat: Double, lon: Double) -> Place {
        let p = Place(name: name, category: "General", address: "")
        p.latitude = lat
        p.longitude = lon
        return p
    }

    private func makeUnlocatedPlace(name: String) -> Place {
        Place(name: name, category: "General", address: "")
    }

    // MARK: - Testler

    func test_nearestNeighborOrder_koordinatsizMekanlarSonaEklenir() {
        let a = makePlace(name: "A", lat: 41.0, lon: 28.0)
        let b = makePlace(name: "B", lat: 41.1, lon: 28.0)
        let noCoord = makeUnlocatedPlace(name: "X")

        let result = RouteOrderOptimizer.nearestNeighborOrder(places: [a, b, noCoord], start: nil)

        XCTAssertEqual(result.last?.name, "X", "Koordinatsız mekan en sona gelmeliydi")
        XCTAssertEqual(result.count, 3)
    }

    func test_nearestNeighborOrder_startVerilinceSiralanir() {
        // A (41.0, 28.0), B (41.0, 29.0), C (41.0, 28.1)
        // Başlangıç: 41.0, 27.9 → A'ya 11 km, B'ye ~90 km, C'ye ~11 km (A biraz daha yakın)
        let a = makePlace(name: "A", lat: 41.0, lon: 28.0)
        let b = makePlace(name: "B", lat: 41.0, lon: 29.0)
        let c = makePlace(name: "C", lat: 41.0, lon: 28.1)
        let start = CLLocationCoordinate2D(latitude: 41.0, longitude: 27.9)

        let result = RouteOrderOptimizer.nearestNeighborOrder(places: [b, c, a], start: start)

        // start'a en yakın olan A (lon 28.0, fark 0.1) veya C (lon 28.1, fark 0.2) → A önce
        XCTAssertEqual(result.first?.name, "A")
        XCTAssertEqual(result.count, 3)
    }

    func test_nearestNeighborOrder_startYokkenIlkMekanSabit() {
        let a = makePlace(name: "A", lat: 41.0, lon: 28.0)
        let b = makePlace(name: "B", lat: 41.0, lon: 29.0)
        let c = makePlace(name: "C", lat: 41.0, lon: 28.1)

        let result = RouteOrderOptimizer.nearestNeighborOrder(places: [a, b, c], start: nil)

        XCTAssertEqual(result.first?.name, "A", "start yokken ilk mekan sabit kalmalı")
    }

    func test_nearestNeighborOrder_tekMekanDegismez() {
        let a = makePlace(name: "A", lat: 41.0, lon: 28.0)
        let result = RouteOrderOptimizer.nearestNeighborOrder(places: [a], start: nil)
        XCTAssertEqual(result.map(\.name), ["A"])
    }
}
