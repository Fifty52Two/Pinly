import Foundation

// MARK: - StarterRoute Modelleri (eski basit format — StarterRoutes.json)

struct StarterRoutePlace: Codable {
    let name: String
    let category: String
    let address: String
    let latitude: Double
    let longitude: Double
}

struct StarterRouteDefinition: Codable, Identifiable {
    var id: String { name }
    let name: String
    let routeCategory: String
    let places: [StarterRoutePlace]
}

// MARK: - Rota Kataloğu Modelleri (`pinly-route-catalog-v1` — content/routes/<country>/<city>.json)
//
// FAZ 4 "Hazır Rota Fabrikası": şehir başına 5 dilli isim/açıklama + `verified` bayrağı
// taşıyan zengin katalog formatı. Eski `StarterRouteDefinition` formatını KIRMAZ —
// ayrı bir tip/yol olarak eklendi, `loadAll()`/`makeSavedRoute(from: StarterRouteDefinition)`
// aynen çalışmaya devam eder.

/// 5 dilde metin — `name`/`description` alanları için. Katalog JSON'undaki `{tr,en,es,de,ru}`
/// objesiyle birebir eşleşir.
struct LocalizedRouteText: Codable, Equatable {
    let tr: String
    let en: String
    let es: String
    let de: String
    let ru: String

    /// Uygulamanın aktif dil koduna göre metni döndürür; bilinmeyen/boş kodda TR'ye düşer.
    func localized(for languageCode: String) -> String {
        switch languageCode {
        case "en": return en
        case "es": return es
        case "de": return de
        case "ru": return ru
        default:   return tr
        }
    }
}

struct RouteCatalogPlace: Codable {
    let name: String
    let category: String
    let address: String
    let latitude: Double
    let longitude: Double
}

struct RouteCatalogEntry: Codable, Identifiable, Equatable {
    let id: String
    let verified: Bool
    let routeCategory: String
    let name: LocalizedRouteText
    let description: LocalizedRouteText
    let places: [RouteCatalogPlace]

    static func == (lhs: RouteCatalogEntry, rhs: RouteCatalogEntry) -> Bool { lhs.id == rhs.id }
}

/// Katalog dosyasının kökü — `_meta` yalnızca bilgi amaçlı, kod hiçbir alanına dayanmaz
/// (format sürümü ileride değişirse burada ayrım yapılabilir).
private struct RouteCatalogFile: Codable {
    struct Meta: Codable {
        let format: String
    }
    let _meta: Meta?
    let city: String
    let country: String
    let routes: [RouteCatalogEntry]
}

// MARK: - StarterCityMatcher
//
// Kullanıcının konumundan (LocationManager.currentCity/currentDistrict) gelen serbest
// metni katalogdaki `city` alanıyla eşleştiren SAF fonksiyon — unit test edilir.
enum StarterCityMatcher {
    private static let turkishFold: [Character: Character] = [
        "ı": "i", "İ": "i", "I": "i",
        "ş": "s", "Ş": "s",
        "ğ": "g", "Ğ": "g",
        "ü": "u", "Ü": "u",
        "ö": "o", "Ö": "o",
        "ç": "c", "Ç": "c"
    ]

    /// "İstanbul" / "ISTANBUL" / " istanbul " gibi varyasyonları aynı anahtara indirger.
    static func normalize(_ raw: String) -> String {
        let folded = String(raw.map { turkishFold[$0] ?? $0 })
        return folded.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `rawLocality` (district ya da şehir adı) bilinen katalog şehirlerinden birine karşılık
    /// geliyorsa normalize edilmiş şehir adını döner; eşleşme yoksa `nil` (çağıran taraf
    /// NearbySearching fallback'ine düşmeli — henüz her şehrin kataloğu yok).
    static func matchCity(from rawLocality: String, knownCities: [String] = ["istanbul"]) -> String? {
        let normalized = normalize(rawLocality)
        guard !normalized.isEmpty else { return nil }
        return knownCities.first { known in
            normalized == known || normalized.contains(known)
        }
    }
}

// MARK: - StarterRoutesProviding

/// Bundle'a gömülü hazır rotaların tek kaynağı — boş uygulama problemi için.
protocol StarterRoutesProviding {
    // Eski basit format (StarterRoutes.json) — geriye dönük uyumluluk.
    func loadAll() -> [StarterRouteDefinition]
    func makeSavedRoute(from definition: StarterRouteDefinition) -> SavedRoute

    /// Zengin katalog formatından, verilen şehre ait DOĞRULANMIŞ (`verified == true`) rotaları
    /// döner. Şehir bilinmiyorsa/katalog yoksa boş dizi (crash etmez).
    func loadCityCatalog(city: String) -> [RouteCatalogEntry]
    /// Katalog girdisini `SavedRoute`'a çevirir — isim/açıklama aktif dile göre seçilir,
    /// kategori `PlaceCategory.from(_:)` ile kanonik rawValue'ya eşlenir (tanınmayan kategori
    /// `.general`'a düşer, crash etmez).
    func makeSavedRoute(from entry: RouteCatalogEntry, languageCode: String) -> SavedRoute
}

struct DefaultStarterRoutesProvider: StarterRoutesProviding {
    /// Bilinen katalog dosyaları — Dalga 1 ilerledikçe buraya yeni (country, filename) çiftleri
    /// eklenir (bkz. GROWTH_PLAN FAZ 4). Dosya adı `city` alanıyla aynı olmak ZORUNDA değil,
    /// eşleşme içerik üzerinden (`RouteCatalogFile.city`) yapılır.
    private static let knownCatalogFiles: [(country: String, filename: String)] = [
        ("tr", "istanbul"),
        ("tr", "ankara"),
        ("tr", "izmir"),
        ("tr", "bursa"),
        ("tr", "antalya"),
        ("tr", "eskisehir"),
        ("tr", "gaziantep"),
        ("tr", "trabzon"),
        ("tr", "mardin"),
        ("tr", "kapadokya"),
        ("fr", "paris"),
        ("it", "roma"),
        ("es", "barcelona"),
        ("nl", "amsterdam"),
        ("de", "berlin"),
        ("cz", "praha"),
        ("at", "wien"),
        ("hu", "budapest"),
        ("gb", "london")
    ]

    func loadAll() -> [StarterRouteDefinition] {
        guard let url = Bundle.main.url(forResource: "StarterRoutes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let defs = try? JSONDecoder().decode([StarterRouteDefinition].self, from: data)
        else { return [] }
        return defs
    }

    func makeSavedRoute(from definition: StarterRouteDefinition) -> SavedRoute {
        let snapshots = definition.places.enumerated().map { index, place in
            SavedPlaceSnapshot(
                name: place.name,
                category: place.category,
                address: place.address,
                notes: "",
                latitude: place.latitude,
                longitude: place.longitude,
                sortIndex: index
            )
        }
        let count = Double(max(definition.places.count, 1))
        return SavedRoute(
            name: definition.name,
            categoryRaw: definition.routeCategory,
            centerLatitude: definition.places.map(\.latitude).reduce(0, +) / count,
            centerLongitude: definition.places.map(\.longitude).reduce(0, +) / count,
            snapshots: snapshots
        )
    }

    func loadCityCatalog(city: String) -> [RouteCatalogEntry] {
        // BUG FİX (FAZ 4 Dalga 1, Sonnet): önceki sürüm `matchCity(from:)`'i knownCities
        // parametresi VERMEDEN çağırıyordu → fonksiyonun varsayılan değeri (yalnızca
        // ["istanbul"]) kullanılıyordu. Sonuç: `knownCatalogFiles`'a yeni şehir eklense bile
        // `loadCityCatalog` o şehri asla eşleştiremiyordu (Ankara/İzmir/Bursa sessizce boş
        // dönerdi). Artık bilinen şehir listesi katalog dosyalarının GERÇEK `city` alanından
        // türetiliyor — yeni bir dosya `knownCatalogFiles`'a eklendiği an otomatik tanınır.
        let catalogFiles = Self.knownCatalogFiles
            .compactMap { Self.loadCatalogFile(country: $0.country, filename: $0.filename) }
        let knownCities = catalogFiles.map { StarterCityMatcher.normalize($0.city) }
        guard let matched = StarterCityMatcher.matchCity(from: city, knownCities: knownCities) else { return [] }
        return catalogFiles
            .filter { StarterCityMatcher.normalize($0.city) == matched }
            .flatMap(\.routes)
            .filter(\.verified)
    }

    func makeSavedRoute(from entry: RouteCatalogEntry, languageCode: String) -> SavedRoute {
        let snapshots = entry.places.enumerated().map { index, place in
            SavedPlaceSnapshot(
                name: place.name,
                // Katalogdaki İngilizce kategori adı kanonik rawValue'ya eşlenir; tanınmayan
                // bir değer gelirse (yazım hatası, gelecekte yeni kategori) `.general`'a düşer.
                category: PlaceCategory.from(place.category).rawValue,
                address: place.address,
                notes: "",
                latitude: place.latitude,
                longitude: place.longitude,
                sortIndex: index
            )
        }
        let count = Double(max(entry.places.count, 1))
        return SavedRoute(
            name: entry.name.localized(for: languageCode),
            categoryRaw: entry.routeCategory,
            centerLatitude: entry.places.map(\.latitude).reduce(0, +) / count,
            centerLongitude: entry.places.map(\.longitude).reduce(0, +) / count,
            snapshots: snapshots
        )
    }

    /// Bundle'da katalog dosyasını bulur — Xcode'un dosya-sistemi senkron grubu klasör
    /// hiyerarşisini koruyabilir (`Routes/tr/istanbul.json`) ya da düzleştirebilir
    /// (`istanbul.json` bundle kökünde); ikisi de denenir.
    private static func loadCatalogFile(country: String, filename: String) -> RouteCatalogFile? {
        let candidates: [String?] = ["Routes/\(country)", nil]
        for subdirectory in candidates {
            if let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: subdirectory),
               let data = try? Data(contentsOf: url),
               let file = try? JSONDecoder().decode(RouteCatalogFile.self, from: data) {
                return file
            }
        }
        return nil
    }
}
