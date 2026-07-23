import XCTest
import CoreLocation
@testable import Pinly

@MainActor
final class RouteSegmentPlannerTests: XCTestCase {

    private func located(_ name: String, lat: Double, lon: Double) -> Place {
        let place = Place(name: name)
        place.latitude = lat
        place.longitude = lon
        return place
    }

    private func unlocated(_ name: String) -> Place {
        Place(name: name)
    }

    /// Invariant: dönen plan HER ZAMAN routePlaces ile aynı uzunlukta olmalı —
    /// aksi halde segment[i] ↔ routePlaces[i] hizası kayar (bilinen bug sınıfı).
    func test_plan_countAlwaysMatchesPlacesCount() {
        let places = [
            located("A", lat: 41.0, lon: 29.0),
            unlocated("B"),
            located("C", lat: 41.02, lon: 29.02),
            unlocated("D"),
            located("E", lat: 41.04, lon: 29.04)
        ]

        let plan = RouteSegmentPlanner.plan(places: places, userLocation: nil)

        XCTAssertEqual(plan.count, places.count)
    }

    func test_plan_userLocationNil_firstLegIsNilPlaceholder() {
        let places = [located("A", lat: 41.0, lon: 29.0), located("B", lat: 41.01, lon: 29.01)]

        let plan = RouteSegmentPlanner.plan(places: places, userLocation: nil)

        XCTAssertNil(plan[0])
        XCTAssertNotNil(plan[1])
        XCTAssertEqual(plan[1]?.from.latitude, 41.0)
        XCTAssertEqual(plan[1]?.to.latitude, 41.01)
    }

    func test_plan_userLocationPresent_allLegsPlanned() {
        let user = CLLocationCoordinate2D(latitude: 40.99, longitude: 28.99)
        let places = [located("A", lat: 41.0, lon: 29.0), located("B", lat: 41.01, lon: 29.01)]

        let plan = RouteSegmentPlanner.plan(places: places, userLocation: user)

        XCTAssertNotNil(plan[0])
        XCTAssertEqual(plan[0]?.from.latitude, 40.99)
        XCTAssertEqual(plan[0]?.to.latitude, 41.0)
        XCTAssertNotNil(plan[1])
        XCTAssertEqual(plan[1]?.from.latitude, 41.0)
        XCTAssertEqual(plan[1]?.to.latitude, 41.01)
    }

    /// Koordinatsız bir durak listenin ortasındaysa: kendi bacağı nil olur, ama
    /// SONRAKİ koordinatlı durak ondan ÖNCEKİ koordinatlı duraktan bacak kurar
    /// (cursor atlanan durakta güncellenmez) — hizası kaymamalı, çifte doğru bağlanmalı.
    func test_plan_unlocatedStopInMiddle_ownLegNil_nextLegSkipsToLastKnownCoordinate() {
        let places = [
            located("A", lat: 41.0, lon: 29.0),
            unlocated("B"),
            located("C", lat: 41.02, lon: 29.02)
        ]

        let plan = RouteSegmentPlanner.plan(places: places, userLocation: nil)

        XCTAssertEqual(plan.count, 3)
        XCTAssertNil(plan[0])   // userLocation yok, ilk durak
        XCTAssertNil(plan[1])   // B koordinatsız — hedefi bilinmiyor
        XCTAssertNotNil(plan[2])
        XCTAssertEqual(plan[2]?.from.latitude, 41.0)   // A'dan (B atlanarak)
        XCTAssertEqual(plan[2]?.to.latitude, 41.02)
    }

    func test_plan_allUnlocated_allNil() {
        let places = [unlocated("A"), unlocated("B")]

        let plan = RouteSegmentPlanner.plan(places: places, userLocation: nil)

        XCTAssertEqual(plan.count, 2)
        XCTAssertTrue(plan.allSatisfy { $0 == nil })
    }

    func test_plan_emptyPlaces_emptyPlan() {
        let plan = RouteSegmentPlanner.plan(places: [], userLocation: nil)

        XCTAssertTrue(plan.isEmpty)
    }
}
