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
        XCTAssertEqual(AnalyticsEvent.paywallShown(source: "limit_reached").name, "paywall_shown")
        XCTAssertEqual(AnalyticsEvent.nearbySearch(category: "cafe").name, "nearby_search")
        XCTAssertEqual(AnalyticsEvent.trialStarted(product: "pinly_pro_yearly").name, "trial_started")
        XCTAssertEqual(AnalyticsEvent.purchaseCompleted(product: "pinly_pro_monthly").name, "purchase_completed")
        XCTAssertEqual(AnalyticsEvent.restoreCompleted.name, "restore_completed")
        XCTAssertEqual(AnalyticsEvent.starterRouteAdopted(source: "nearby_fallback").name, "starter_route_adopted")
    }

    func test_starterRouteAdopted_parametersContainSource() {
        XCTAssertEqual(AnalyticsEvent.starterRouteAdopted(source: "ist-tarihi-yarimada").parameters["source"], "ist-tarihi-yarimada")
    }

    func test_placeAdded_parametersContainSource() {
        let params = AnalyticsEvent.placeAdded(source: .qr).parameters
        XCTAssertEqual(params["source"], "qr")
    }

    func test_nearbySearch_parametersContainCategory() {
        let params = AnalyticsEvent.nearbySearch(category: "museum").parameters
        XCTAssertEqual(params["category"], "museum")
    }

    func test_paywallShown_parametersContainSource() {
        XCTAssertEqual(AnalyticsEvent.paywallShown(source: "first_route_completed").parameters["source"], "first_route_completed")
    }

    func test_purchaseEvents_parametersContainProduct() {
        XCTAssertEqual(AnalyticsEvent.trialStarted(product: "pinly_pro_yearly").parameters["product"], "pinly_pro_yearly")
        XCTAssertEqual(AnalyticsEvent.purchaseCompleted(product: "pinly_pro_monthly").parameters["product"], "pinly_pro_monthly")
    }

    func test_parameterlessEvents_haveEmptyParameters() {
        XCTAssertTrue(AnalyticsEvent.routeStarted.parameters.isEmpty)
        XCTAssertTrue(AnalyticsEvent.restoreCompleted.parameters.isEmpty)
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
