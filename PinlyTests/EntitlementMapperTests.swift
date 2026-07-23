import XCTest
import RevenueCat
@testable import Pinly

/// `EntitlementMapper.isPro` RevenueCat SDK'dan bağımsız test edilebilir saf fonksiyon —
/// gerçek `CustomerInfo` RC'nin sunucu yanıtıyla birebir aynı JSON şemasından `Decodable`
/// aracılığıyla kurulur (RC'nin kendi testlerinde kullandığı yöntem). Bir entitlement'ın
/// `all` sözlüğünde görünmesi için `subscriptions` altında AYNI `product_identifier`'a
/// sahip bir kayıt da şart — yoksa RC onu sessizce düşürür (`EntitlementInfos.swift`).
final class EntitlementMapperTests: XCTestCase {
    private func makeCustomerInfo(
        productIdentifier: String,
        expiresDate: String,
        includeMatchingSubscription: Bool = true
    ) throws -> CustomerInfo {
        let entitlementsBlock = """
        "pro": {
            "expires_date": "\(expiresDate)",
            "product_identifier": "\(productIdentifier)",
            "purchase_date": "2026-01-01T00:00:00Z"
        }
        """
        let subscriptionsBlock = includeMatchingSubscription ? """
        "\(productIdentifier)": {
            "expires_date": "\(expiresDate)",
            "purchase_date": "2026-01-01T00:00:00Z",
            "original_purchase_date": "2026-01-01T00:00:00Z",
            "store": "app_store",
            "is_sandbox": true
        }
        """ : ""

        let json = """
        {
          "request_date": "2026-07-23T10:00:00Z",
          "request_date_ms": 1784894400000,
          "subscriber": {
            "first_seen": "2026-01-01T00:00:00Z",
            "original_app_user_id": "test_user",
            "original_application_version": "1.0",
            "entitlements": { \(entitlementsBlock) },
            "subscriptions": { \(subscriptionsBlock) },
            "other_purchases": {}
          }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        // RevenueCat'in kendi backend decoder'ıyla aynı sözleşme: snake_case anahtarlar +
        // ISO8601 tarihler (RC'nin internal `JSONDecoder.default`'ı public değil, burada
        // aynı ayarla yeniden kuruluyor).
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CustomerInfo.self, from: data)
    }

    func test_isPro_true_whenActivePro() throws {
        let info = try makeCustomerInfo(productIdentifier: "pinly_pro_yearly", expiresDate: "2100-01-01T00:00:00Z")
        XCTAssertTrue(EntitlementMapper.isPro(customerInfo: info))
    }

    func test_isPro_false_whenExpired() throws {
        let info = try makeCustomerInfo(productIdentifier: "pinly_pro_monthly", expiresDate: "2020-01-01T00:00:00Z")
        XCTAssertFalse(EntitlementMapper.isPro(customerInfo: info))
    }

    func test_isPro_false_whenNoMatchingSubscription() throws {
        // RC, subscriptions'ta karşılığı olmayan entitlement'ı `all`'dan tamamen düşürür.
        let info = try makeCustomerInfo(
            productIdentifier: "pinly_pro_yearly",
            expiresDate: "2100-01-01T00:00:00Z",
            includeMatchingSubscription: false
        )
        XCTAssertFalse(EntitlementMapper.isPro(customerInfo: info))
    }

    func test_isPro_false_whenNoEntitlementAtAll() throws {
        let json = """
        {
          "request_date": "2026-07-23T10:00:00Z",
          "request_date_ms": 1784894400000,
          "subscriber": {
            "first_seen": "2026-01-01T00:00:00Z",
            "original_app_user_id": "test_user",
            "original_application_version": "1.0",
            "entitlements": {},
            "subscriptions": {},
            "other_purchases": {}
          }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let info = try decoder.decode(CustomerInfo.self, from: data)
        XCTAssertFalse(EntitlementMapper.isPro(customerInfo: info))
    }
}
