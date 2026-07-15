import XCTest
@testable import Pinly

/// Event isim/parametre sözleşmesi Firebase `logEvent` ile uyumlu snake_case olmalı —
/// bu isimler Firebase Console'daki event tanımlarıyla birebir eşleşir, yanlışlıkla
/// değiştirilirse dashboard'daki event geçmişi kopar.
final class AnalyticsEventTests: XCTestCase {
    func test_eventNames_matchSnakeCaseContract() {
        XCTAssertEqual(AnalyticsEvent.placeAdded(source: .manual).name, "place_added")
        XCTAssertEqual(AnalyticsEvent.routeStarted.name, "route_started")
        XCTAssertEqual(AnalyticsEvent.routeCompleted.name, "route_completed")
        XCTAssertEqual(AnalyticsEvent.routeShared.name, "route_shared")
        XCTAssertEqual(AnalyticsEvent.paywallShown.name, "paywall_shown")
        XCTAssertEqual(AnalyticsEvent.nearbySearch(category: "cafe").name, "nearby_search")
    }

    func test_placeAdded_parametersContainSource() {
        let params = AnalyticsEvent.placeAdded(source: .qr).parameters
        XCTAssertEqual(params["source"], "qr")
    }

    func test_nearbySearch_parametersContainCategory() {
        let params = AnalyticsEvent.nearbySearch(category: "museum").parameters
        XCTAssertEqual(params["category"], "museum")
    }

    func test_parameterlessEvents_haveEmptyParameters() {
        XCTAssertTrue(AnalyticsEvent.routeStarted.parameters.isEmpty)
        XCTAssertTrue(AnalyticsEvent.paywallShown.parameters.isEmpty)
    }

    func test_allPlaceAddSources_haveSnakeCaseRawValues() {
        let expected: [PlaceAddSource: String] = [
            .manual: "manual", .qr: "qr", .deeplink: "deeplink", .swarm: "swarm",
            .nearby: "nearby", .quickAdd: "quick_add", .routeImport: "route_import"
        ]
        for (source, raw) in expected {
            XCTAssertEqual(source.rawValue, raw)
        }
    }
}
