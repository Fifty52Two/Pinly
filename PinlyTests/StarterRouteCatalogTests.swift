import XCTest
@testable import Pinly

/// FAZ 4 "Hazır Rota Fabrikası": zengin katalog formatı (`pinly-route-catalog-v1`) —
/// `content/routes/tr/istanbul.json`'dan `Pinly/Resources/Routes/tr/istanbul.json`'a
/// kopyalanan dosyayı okur. Eski basit format testleri `StarterRoutesProviderTests`'te.
final class StarterRouteCatalogTests: XCTestCase {
    private let provider = DefaultStarterRoutesProvider()

    func test_loadCityCatalog_istanbul_returnsOnlyVerifiedRoutes() {
        let entries = provider.loadCityCatalog(city: "İstanbul")
        XCTAssertFalse(entries.isEmpty, "İstanbul kataloğu boş dönmemeli")
        XCTAssertTrue(entries.allSatisfy(\.verified), "yalnızca verified:true rotalar dönmeli")
        // Katalog dosyasında 3 verified + 5 verified:false rota var — 3 bekleniyor.
        XCTAssertEqual(entries.count, 3)
    }

    func test_loadCityCatalog_turkceKarakterVeBuyukKucukHarfToleransli() {
        let variants = ["istanbul", "ISTANBUL", "İstanbul", "  Istanbul  "]
        for variant in variants {
            XCTAssertFalse(provider.loadCityCatalog(city: variant).isEmpty, "eşleşmeli: \(variant)")
        }
    }

    func test_loadCityCatalog_bilinmeyenSehir_bosDizi() {
        XCTAssertTrue(provider.loadCityCatalog(city: "Ankara").isEmpty)
        XCTAssertTrue(provider.loadCityCatalog(city: "").isEmpty)
    }

    func test_loadCityCatalog_koordinatlarIstanbulSinirlarinda() {
        for entry in provider.loadCityCatalog(city: "istanbul") {
            for place in entry.places {
                XCTAssertTrue((40.8...41.3).contains(place.latitude), place.name)
                XCTAssertTrue((28.5...29.3).contains(place.longitude), place.name)
            }
        }
    }

    func test_makeSavedRoute_fromCatalogEntry_localizesNameByLanguage() throws {
        let entry = try XCTUnwrap(provider.loadCityCatalog(city: "istanbul").first)
        let tr = provider.makeSavedRoute(from: entry, languageCode: "tr")
        let en = provider.makeSavedRoute(from: entry, languageCode: "en")
        XCTAssertEqual(tr.name, entry.name.tr)
        XCTAssertEqual(en.name, entry.name.en)
        XCTAssertNotEqual(tr.name, en.name)
    }

    func test_makeSavedRoute_fromCatalogEntry_snapshotCategoriesAreCanonicalRawValues() throws {
        let entry = try XCTUnwrap(provider.loadCityCatalog(city: "istanbul").first { $0.id == "ist-tarihi-yarimada" })
        let saved = provider.makeSavedRoute(from: entry, languageCode: "tr")
        let canonicalValues = Set(PlaceCategory.allCases.map(\.rawValue))
        for snapshot in saved.placeSnapshots {
            XCTAssertTrue(canonicalValues.contains(snapshot.category), "beklenmeyen kategori: \(snapshot.category)")
        }
        XCTAssertEqual(saved.placeSnapshots.map(\.sortIndex), Array(0..<entry.places.count))
    }

    func test_makeSavedRoute_fromCatalogEntry_bilinmeyenKategoriGeneleDuser() {
        let weirdEntry = RouteCatalogEntry(
            id: "test-weird",
            verified: true,
            routeCategory: "Şehir İçi",
            name: LocalizedRouteText(tr: "Test", en: "Test", es: "Test", de: "Test", ru: "Test"),
            description: LocalizedRouteText(tr: "", en: "", es: "", de: "", ru: ""),
            places: [
                RouteCatalogPlace(name: "Bilinmeyen Yer", category: "Alien Zone", address: "", latitude: 41.0, longitude: 29.0)
            ]
        )
        let saved = provider.makeSavedRoute(from: weirdEntry, languageCode: "tr")
        XCTAssertEqual(saved.placeSnapshots.first?.category, PlaceCategory.general.rawValue)
    }

    func test_localizedRouteText_unknownLanguageFallsBackToTurkish() {
        let text = LocalizedRouteText(tr: "Türkçe", en: "English", es: "Español", de: "Deutsch", ru: "Русский")
        XCTAssertEqual(text.localized(for: "fr"), "Türkçe")
        XCTAssertEqual(text.localized(for: "en"), "English")
    }
}

// MARK: - StarterCityMatcher

final class StarterCityMatcherTests: XCTestCase {
    func test_normalize_turkceKarakterleriAsciiyeCevirir() {
        XCTAssertEqual(StarterCityMatcher.normalize("İSTANBUL"), "istanbul")
        XCTAssertEqual(StarterCityMatcher.normalize("Üsküdar"), "uskudar")
        XCTAssertEqual(StarterCityMatcher.normalize("  Çankaya  "), "cankaya")
    }

    func test_matchCity_bilinenSehirVaryasyonlariEslesir() {
        XCTAssertEqual(StarterCityMatcher.matchCity(from: "İstanbul"), "istanbul")
        XCTAssertEqual(StarterCityMatcher.matchCity(from: "ISTANBUL"), "istanbul")
        XCTAssertEqual(StarterCityMatcher.matchCity(from: "Istanbul Province"), "istanbul")
    }

    func test_matchCity_bilinmeyenSehir_nilDoner() {
        XCTAssertNil(StarterCityMatcher.matchCity(from: "Ankara"))
        XCTAssertNil(StarterCityMatcher.matchCity(from: ""))
    }

    func test_matchCity_ilceAdiSehirIcermiyorsaNilDoner() {
        // currentDistrict district önceliklidir ("Kadıköy") — bu saf fonksiyon şehir
        // adını ARAR, ilçe→şehir bilgisini kendisi TÜRETMEZ (bilinçli sınırlama, bkz. rapor).
        XCTAssertNil(StarterCityMatcher.matchCity(from: "Kadıköy"))
    }
}
