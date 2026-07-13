import XCTest
@testable import Pinly

@MainActor
final class DefaultBadgeServiceTests: XCTestCase {
    private func makeService(suiteName: String) -> DefaultBadgeService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return DefaultBadgeService(defaults: defaults)
    }

    // MARK: - check(placeStore:) thresholds

    func test_check_zeroPlaces_unlocksNoPlaceBadges() {
        let service = makeService(suiteName: #function)
        let repository = MockPlaceRepository()

        let unlocked = service.check(placeStore: repository)

        XCTAssertFalse(unlocked.contains(.ilkAdim))
    }

    func test_check_onePlace_unlocksIlkAdim() {
        let service = makeService(suiteName: #function)
        let repository = MockPlaceRepository()
        repository.places = [Place(name: "Tek Mekan")]

        let unlocked = service.check(placeStore: repository)

        XCTAssertTrue(unlocked.contains(.ilkAdim))
        XCTAssertTrue(service.unlockedBadges.contains(.ilkAdim))
    }

    func test_check_fivePlaces_unlocksIlkAdimAndBesli() {
        let service = makeService(suiteName: #function)
        let repository = MockPlaceRepository()
        repository.places = (1...5).map { Place(name: "Mekan \($0)") }

        let unlocked = service.check(placeStore: repository)

        XCTAssertTrue(unlocked.contains(.ilkAdim))
        XCTAssertTrue(unlocked.contains(.besli))
        XCTAssertFalse(unlocked.contains(.onlu))
    }

    func test_check_alreadyUnlockedBadge_notReturnedAgain() {
        let service = makeService(suiteName: #function)
        let repository = MockPlaceRepository()
        repository.places = [Place(name: "Tek Mekan")]

        _ = service.check(placeStore: repository)
        let secondCheck = service.check(placeStore: repository)

        XCTAssertTrue(secondCheck.isEmpty)
    }

    // MARK: - recordAppOpen streak

    func test_recordAppOpen_firstEverOpen_setsStreakToOne() {
        let service = makeService(suiteName: #function)
        service.recordAppOpen()
        XCTAssertEqual(service.consecutiveDays, 1)
    }

    func test_recordAppOpen_sameDayTwice_doesNotIncrementStreak() {
        let service = makeService(suiteName: #function)
        service.recordAppOpen()
        service.recordAppOpen()
        XCTAssertEqual(service.consecutiveDays, 1)
    }

    func test_recordAppOpen_consecutiveDay_incrementsStreak() {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        defaults.set(Calendar.current.startOfDay(for: yesterday), forKey: "pinly.lastOpenDate")
        defaults.set(3, forKey: "pinly.consecutiveDays")

        let service = DefaultBadgeService(defaults: defaults)
        service.recordAppOpen()

        XCTAssertEqual(service.consecutiveDays, 4)
    }

    func test_recordAppOpen_skippedDay_resetsStreakToOne() {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        defaults.set(Calendar.current.startOfDay(for: threeDaysAgo), forKey: "pinly.lastOpenDate")
        defaults.set(5, forKey: "pinly.consecutiveDays")

        let service = DefaultBadgeService(defaults: defaults)
        service.recordAppOpen()

        XCTAssertEqual(service.consecutiveDays, 1)
    }
}
