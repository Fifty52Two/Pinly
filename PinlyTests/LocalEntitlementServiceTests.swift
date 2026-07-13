import XCTest
@testable import Pinly

final class LocalEntitlementServiceTests: XCTestCase {
    private func makeService(suiteName: String) -> LocalEntitlementService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return LocalEntitlementService(defaults: defaults)
    }

    func test_freeUser_canAddPlace_belowLimit() {
        let service = makeService(suiteName: #function)
        XCTAssertTrue(service.canAddPlace(currentCount: 19))
    }

    func test_freeUser_cannotAddPlace_atLimit() {
        let service = makeService(suiteName: #function)
        XCTAssertFalse(service.canAddPlace(currentCount: 20))
    }

    func test_proUser_hasNoLimit() {
        let service = makeService(suiteName: #function)
        service.isPro = true
        XCTAssertTrue(service.canAddPlace(currentCount: 500))
    }

    func test_legacyNotionGoKey_migratesToNewProKey() {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "notiongo.isPro")

        let service = LocalEntitlementService(defaults: defaults)
        XCTAssertTrue(service.isPro)
        XCTAssertTrue(defaults.bool(forKey: "pinly.isPro"))
    }

    func test_settingIsPro_removesLegacyKey() {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "notiongo.isPro")

        let service = LocalEntitlementService(defaults: defaults)
        service.isPro = false

        XCTAssertNil(defaults.object(forKey: "notiongo.isPro"))
        XCTAssertFalse(service.isPro)
    }

    func test_freeLimit_isTwenty() {
        let service = makeService(suiteName: #function)
        XCTAssertEqual(service.freeLimit, 20)
    }
}
