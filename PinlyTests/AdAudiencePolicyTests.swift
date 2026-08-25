import XCTest
@testable import Pinly

final class AdAudiencePolicyTests: XCTestCase {
    func test_unknownProfile_remainsUnknown() {
        XCTAssertEqual(AdAudiencePolicy.category(profile: nil, currentYear: 2026), .unknown)
    }

    func test_underThirteen_isChild() {
        let profile = UserProfile(firstName: "A", lastName: "B", birthYear: 2014)
        XCTAssertEqual(AdAudiencePolicy.category(profile: profile, currentYear: 2026), .child)
    }

    func test_thirteenYearDifference_staysChildBecauseBirthdayIsUnknown() {
        let profile = UserProfile(firstName: "A", lastName: "B", birthYear: 2013)
        XCTAssertEqual(AdAudiencePolicy.category(profile: profile, currentYear: 2026), .child)
    }

    func test_thirteenToFifteen_isTeen() {
        let profile = UserProfile(firstName: "A", lastName: "B", birthYear: 2011)
        XCTAssertEqual(AdAudiencePolicy.category(profile: profile, currentYear: 2026), .teen)
    }

    func test_sixteenYearDifference_staysTeenBecauseBirthdayIsUnknown() {
        let profile = UserProfile(firstName: "A", lastName: "B", birthYear: 2010)
        XCTAssertEqual(AdAudiencePolicy.category(profile: profile, currentYear: 2026), .teen)
    }

    func test_seventeenYearDifference_isAdult() {
        let profile = UserProfile(firstName: "A", lastName: "B", birthYear: 2009)
        XCTAssertEqual(AdAudiencePolicy.category(profile: profile, currentYear: 2026), .adult)
    }
}
