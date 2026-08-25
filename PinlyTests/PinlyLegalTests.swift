import XCTest
@testable import Pinly

final class PinlyLegalTests: XCTestCase {
    func test_websiteURLsRequireAPlainHTTPSHost() {
        XCTAssertEqual(
            PinlyLegal.makeWebsiteURL(hostValue: "Example.COM", path: "/privacy/")?.absoluteString,
            "https://example.com/privacy/"
        )
        XCTAssertNil(PinlyLegal.makeWebsiteURL(hostValue: "", path: "/privacy/"))
        XCTAssertNil(PinlyLegal.makeWebsiteURL(hostValue: "https://example.com", path: "/privacy/"))
        XCTAssertNil(PinlyLegal.makeWebsiteURL(hostValue: "example.com/path", path: "/privacy/"))
        XCTAssertNil(PinlyLegal.makeWebsiteURL(hostValue: "localhost", path: "/privacy/"))
        XCTAssertNil(PinlyLegal.makeWebsiteURL(hostValue: "exa mple.com", path: "/privacy/"))
        XCTAssertNil(PinlyLegal.makeWebsiteURL(hostValue: "example..com", path: "/privacy/"))
        XCTAssertNil(PinlyLegal.makeWebsiteURL(hostValue: "-example.com", path: "/privacy/"))
        XCTAssertNil(PinlyLegal.makeWebsiteURL(hostValue: "example.com", path: "privacy"))
    }

    func test_appStoreURLRequiresNumericIdentifier() {
        XCTAssertEqual(
            PinlyLegal.makeAppStoreURL(idValue: " 1234567890 ")?.absoluteString,
            "https://apps.apple.com/app/id1234567890"
        )
        XCTAssertNil(PinlyLegal.makeAppStoreURL(idValue: nil))
        XCTAssertNil(PinlyLegal.makeAppStoreURL(idValue: "id123"))
        XCTAssertNil(PinlyLegal.makeAppStoreURL(idValue: "123/456"))
        XCTAssertNil(PinlyLegal.makeAppStoreURL(idValue: "１２３"))
    }
}
