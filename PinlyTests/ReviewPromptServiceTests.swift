import XCTest
@testable import Pinly

final class ReviewPromptServiceTests: XCTestCase {
    private func makeService(suiteName: String) -> DefaultReviewPromptService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return DefaultReviewPromptService(defaults: defaults)
    }

    func test_firstCompletion_doesNotPrompt() {
        let service = makeService(suiteName: #function)
        service.recordRouteCompletion()
        XCTAssertFalse(service.shouldPromptForReview(currentVersion: "1.0"))
    }

    func test_secondCompletion_prompts() {
        let service = makeService(suiteName: #function)
        service.recordRouteCompletion()
        service.recordRouteCompletion()
        XCTAssertTrue(service.shouldPromptForReview(currentVersion: "1.0"))
    }

    func test_sameVersion_neverPromptsTwice() {
        let service = makeService(suiteName: #function)
        service.recordRouteCompletion()
        service.recordRouteCompletion()
        service.markPrompted(version: "1.0")
        service.recordRouteCompletion()
        XCTAssertFalse(service.shouldPromptForReview(currentVersion: "1.0"))
    }

    func test_newVersion_promptsAgain() {
        let service = makeService(suiteName: #function)
        service.recordRouteCompletion()
        service.recordRouteCompletion()
        service.markPrompted(version: "1.0")
        XCTAssertTrue(service.shouldPromptForReview(currentVersion: "1.1"))
    }
}
