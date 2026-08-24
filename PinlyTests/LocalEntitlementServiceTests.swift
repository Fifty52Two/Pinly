import XCTest
@testable import Pinly

final class LocalEntitlementServiceTests: XCTestCase {
    private func makeService(suiteName: String) -> LocalEntitlementService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return LocalEntitlementService(defaults: defaults)
    }

    /// Mekan ekleme artık ücretsiz ve sınırsız — eski 20 mekanlık freemium
    /// limiti kaldırıldı, Pro değer önerisi GPX/PDF export + reklamsız kullanım.
    func test_placeAdding_isUnlimited_forFreeUser() {
        let service = makeService(suiteName: #function)
        XCTAssertTrue(service.canAddPlace(currentCount: 0))
        XCTAssertTrue(service.canAddPlace(currentCount: 20))
        XCTAssertTrue(service.canAddPlace(currentCount: 5_000))
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
}
