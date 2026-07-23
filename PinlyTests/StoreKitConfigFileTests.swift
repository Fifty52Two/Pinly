import XCTest
import StoreKit
import StoreKitTest
import RevenueCat
@testable import Pinly

/// Pinly.storekit dosyasının geçerli olduğunu ve ürün ID'lerinin ASC/RevenueCat tarafıyla
/// senkron kaldığını doğrular. `SKTestSession` testin StoreKit ortamını bu dosyadan kurar —
/// dosya bozulur ya da ürün ID'leri kayarsa burada kırmızıya döner (paywall'ın simülatörde
/// "mağazaya ulaşılamıyor" göstermesinin StoreKit ayağı budur; scheme'deki
/// StoreKitConfigurationFileReference yalnızca Xcode'dan Run için geçerlidir).
final class StoreKitConfigFileTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "Pinly")
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() {
        session = nil
    }

    func test_storeKitConfig_servesBothSubscriptionProducts() async throws {
        let products = try await Product.products(for: ["pinly_pro_monthly", "pinly_pro_yearly"])
        let ids = Set(products.map(\.id))
        XCTAssertEqual(ids, ["pinly_pro_monthly", "pinly_pro_yearly"],
                       "Pinly.storekit geçersiz veya ürün ID'leri kaymış")
    }

    func test_storeKitConfig_yearlyHasFreeTrialIntroOffer() async throws {
        let products = try await Product.products(for: ["pinly_pro_yearly"])
        let yearly = try XCTUnwrap(products.first)
        let intro = try XCTUnwrap(yearly.subscription?.introductoryOffer,
                                  "Yıllık üründe intro offer yok — paywall'daki '7 Gün Ücretsiz' rozeti kaybolur")
        XCTAssertEqual(intro.paymentMode, .freeTrial)
    }

    /// RC zincirinin TAMAMI: backend'den `default` offering gelir, `$rc_monthly`/`$rc_annual`
    /// paketleri lokal StoreKit ürünlerine bağlanır. RC dashboard'da offering/paket/ürün
    /// eşleşmesi bozulursa burada yakalanır. Ağ yoksa test atlanır (fail değil).
    func test_revenueCatOfferings_resolveAgainstStoreKitConfig() async throws {
        let offerings: RevenueCat.Offerings
        do {
            offerings = try await RevenueCatPurchasesService.shared.offerings()
        } catch {
            throw XCTSkip("RevenueCat backend'ine ulaşılamadı (ağ yok?): \(error)")
        }
        let current = try XCTUnwrap(offerings.current, "RC'de current offering yok")
        XCTAssertNotNil(current.monthly, "default offering'de $rc_monthly paketi çözülmedi")
        XCTAssertNotNil(current.annual, "default offering'de $rc_annual paketi çözülmedi")
        XCTAssertEqual(current.monthly?.storeProduct.productIdentifier, "pinly_pro_monthly")
        XCTAssertEqual(current.annual?.storeProduct.productIdentifier, "pinly_pro_yearly")
    }
}
