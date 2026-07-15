import XCTest
import MapKit
@testable import Pinly

/// Yakınımda kategori bug'ının regresyon testleri: adında "park" geçen restoran
/// parklara düşmemeli — sonuç kategorisi MapKit POI kategorisinden doğrulanır.
final class NearbyCategoryResolverTests: XCTestCase {

    // MARK: - poiCategories (arama stratejisi seçimi)

    func test_poiKarsiligiOlanKategoriler_filtreliAranir() {
        XCTAssertEqual(NearbyCategoryResolver.poiCategories(for: .restaurant), [.restaurant])
        XCTAssertEqual(NearbyCategoryResolver.poiCategories(for: .cafe), [.cafe])
        XCTAssertEqual(NearbyCategoryResolver.poiCategories(for: .park), [.park, .nationalPark])
        XCTAssertEqual(NearbyCategoryResolver.poiCategories(for: .museum), [.museum])
        XCTAssertEqual(NearbyCategoryResolver.poiCategories(for: .library), [.library])
        XCTAssertEqual(NearbyCategoryResolver.poiCategories(for: .dessert), [.bakery])
    }

    func test_poiKarsiligiOlmayanKategoriler_metinAramasinaDüşer() {
        XCTAssertNil(NearbyCategoryResolver.poiCategories(for: .historical))
        XCTAssertNil(NearbyCategoryResolver.poiCategories(for: .general))
    }

    // MARK: - resolvedCategory (sonuç doğrulama)

    func test_parkAramasinda_gercekPark_parkOlarakKalir() {
        XCTAssertEqual(
            NearbyCategoryResolver.resolvedCategory(requested: .park, poi: .park),
            .park
        )
        XCTAssertEqual(
            NearbyCategoryResolver.resolvedCategory(requested: .park, poi: .nationalPark),
            .park
        )
    }

    func test_poiBilgisiYoksa_istenenKategoriKullanilir() {
        XCTAssertEqual(
            NearbyCategoryResolver.resolvedCategory(requested: .restaurant, poi: nil),
            .restaurant
        )
    }

    func test_bakerySonucu_dessertOlarakTuretilir() {
        XCTAssertEqual(
            NearbyCategoryResolver.resolvedCategory(requested: .dessert, poi: .bakery),
            .dessert
        )
    }

    func test_tarihiYerAramasinda_restoranSonucu_elenir() {
        // "Tarihi Sultanahmet Köftecisi" gibi adında "tarihi" geçen restoran
        // tarihi yer sekmesine giremez.
        XCTAssertNil(
            NearbyCategoryResolver.resolvedCategory(requested: .historical, poi: .restaurant)
        )
    }

    func test_tarihiYerAramasinda_poiBilinmiyorsa_tarihiKalir() {
        XCTAssertEqual(
            NearbyCategoryResolver.resolvedCategory(requested: .historical, poi: nil),
            .historical
        )
    }

    func test_genelAramada_somutKategori_kendiKategorisiyleGosterilir() {
        XCTAssertEqual(
            NearbyCategoryResolver.resolvedCategory(requested: .general, poi: .cafe),
            .cafe
        )
        XCTAssertEqual(
            NearbyCategoryResolver.resolvedCategory(requested: .general, poi: nil),
            .general
        )
    }
}
