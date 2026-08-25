import XCTest
@testable import Pinly

final class InterstitialFrequencyPolicyTests: XCTestCase {
    private let policy = InterstitialFrequencyPolicy.v1
    private let now = Date(timeIntervalSince1970: 1_000)

    func test_firstPresentationInSessionIsAllowed() {
        XCTAssertTrue(policy.allowsPresentation(now: now, lastShownAt: nil, shownThisSession: 0))
    }

    func test_secondPresentationBeforeSevenMinutesIsBlocked() {
        let sixMinutesAgo = now.addingTimeInterval(-6 * 60)
        XCTAssertFalse(policy.allowsPresentation(now: now, lastShownAt: sixMinutesAgo, shownThisSession: 1))
    }

    func test_secondPresentationAtSevenMinutesIsAllowed() {
        let sevenMinutesAgo = now.addingTimeInterval(-7 * 60)
        XCTAssertTrue(policy.allowsPresentation(now: now, lastShownAt: sevenMinutesAgo, shownThisSession: 1))
    }

    func test_thirdPresentationInSessionIsBlockedRegardlessOfTime() {
        let oneHourAgo = now.addingTimeInterval(-60 * 60)
        XCTAssertFalse(policy.allowsPresentation(now: now, lastShownAt: oneHourAgo, shownThisSession: 2))
    }
}
