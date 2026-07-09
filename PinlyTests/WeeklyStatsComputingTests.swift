import XCTest
@testable import Pinly

final class WeeklyStatsComputingTests: XCTestCase {
    private let computer = DefaultWeeklyStatsComputer()

    func test_computeStats_emptyHistories_returnsZeroed() {
        let stats = computer.computeStats(places: [], histories: [])
        XCTAssertEqual(stats.routesCompleted, 0)
        XCTAssertEqual(stats.totalSteps, 0)
        XCTAssertEqual(stats.totalDistanceMeters, 0)
        XCTAssertTrue(stats.isEmpty)
    }

    func test_computeStats_filtersHistoriesOlderThanWeek() {
        let recent = RouteHistory(
            routeName: "Recent",
            date: Date(),
            placeNames: ["A"],
            totalDistanceMeters: 1000,
            durationSeconds: 600,
            stepCount: 1200
        )
        let old = RouteHistory(
            routeName: "Old",
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            placeNames: ["B"],
            totalDistanceMeters: 5000,
            durationSeconds: 1800,
            stepCount: 6000
        )

        let stats = computer.computeStats(places: [], histories: [recent, old])

        XCTAssertEqual(stats.routesCompleted, 1)
        XCTAssertEqual(stats.totalSteps, 1200)
        XCTAssertEqual(stats.totalDistanceMeters, 1000)
    }

    func test_computeStats_topCategory_picksHighestCount() {
        let places = [
            Place(name: "A", category: PlaceCategory.restaurant.rawValue),
            Place(name: "B", category: PlaceCategory.restaurant.rawValue),
            Place(name: "C", category: PlaceCategory.park.rawValue),
        ]
        let stats = computer.computeStats(places: places, histories: [])
        XCTAssertEqual(stats.topCategory, .restaurant)
    }

    func test_computeStats_topDistrict_picksHighestCount() {
        let a = Place(name: "A", category: PlaceCategory.general.rawValue)
        a.locationName = "Kadıköy, İstanbul"
        let b = Place(name: "B", category: PlaceCategory.general.rawValue)
        b.locationName = "Kadıköy, İstanbul"
        let c = Place(name: "C", category: PlaceCategory.general.rawValue)
        c.locationName = "Beşiktaş, İstanbul"

        let stats = computer.computeStats(places: [a, b, c], histories: [])
        XCTAssertEqual(stats.topDistrict, "Kadıköy")
    }

    func test_computeStats_sumsStepsAndDistance() {
        let h1 = RouteHistory(routeName: "R1", placeNames: [], totalDistanceMeters: 1000, durationSeconds: 600, stepCount: 1000)
        let h2 = RouteHistory(routeName: "R2", placeNames: [], totalDistanceMeters: 2000, durationSeconds: 900, stepCount: 2500)

        let stats = computer.computeStats(places: [], histories: [h1, h2])

        XCTAssertEqual(stats.totalSteps, 3500)
        XCTAssertEqual(stats.totalDistanceMeters, 3000)
        XCTAssertEqual(stats.routesCompleted, 2)
        XCTAssertFalse(stats.isEmpty)
    }
}
