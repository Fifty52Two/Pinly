#!/usr/bin/env swift
//
// Rota kataloğu koordinat doğrulayıcısı (FAZ 4 içerik fabrikası — halüsinasyon filtresi).
// macOS'ta çalışır: swift scripts/verify_routes.swift content/routes/tr/istanbul.json
//
// Her durak için MKLocalSearch ile (mekan adı + şehir) araması yapar, dönen sonuçların
// katalogdaki koordinata uzaklığına bakar:
//   PASS  : en yakın eşleşme ≤ 250 m
//   NEAR  : 250 m – 1 km (elle kontrol önerilir — koordinat büyük olasılıkla kaba)
//   FAIL  : > 1 km ya da hiç sonuç yok (halüsinasyon şüphesi)
// Ayrıca ardışık duraklar arası kuş uçuşu > 2.5 km ise uyarır (yürüme rotası kuralı).
// Çıkış kodu: FAIL varsa 1, yoksa 0. Katalog dosyasını DEĞİŞTİRMEZ — verified bayrağını
// insan (Ferhat) günceller.
//
// BİLİNEN SINIRLAMA (2026-07-23 ilk çalıştırmada görüldü): "category": "General" olan ve
// tek bir POI'ye karşılık gelmeyen genel alan adları ("Kadıköy Tarihî Çarşı", "Beşiktaş
// Çarşı" gibi çarşı/pazar bölgesi isimleri) MKLocalSearch'te metin-benzerliğine göre
// alakasız, uzak bir sonuca (ör. "Carsi Cd." adlı bambaşka bir sokak) eşleşebiliyor —
// bu FAIL, koordinatın yanlış olduğu anlamına GELMEZ, sadece script'in isim-arama yöntemi
// bu tip genel alanlar için güvenilmez demektir. Böyle FAIL'lerde adres alanını (name
// yerine) ayrı bir geocode denemesiyle çapraz kontrol et, otomatik silme/değiştirme yapma.

import Foundation
import MapKit

struct CatalogPlace: Codable {
    let name: String
    let category: String
    let address: String?
    let latitude: Double
    let longitude: Double
}

struct CatalogRoute: Codable {
    let id: String
    let verified: Bool
    let name: [String: String]
    let places: [CatalogPlace]
}

struct Catalog: Codable {
    let city: String
    let routes: [CatalogRoute]
}

guard CommandLine.arguments.count > 1 else {
    print("kullanım: swift scripts/verify_routes.swift <katalog.json>")
    exit(2)
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))

func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}

/// MKLocalSearch senkron sarmalayıcı — completion main runloop'ta gelir, script
/// runloop'u elle pompalar. Apple istekleri kısıtlamasın diye çağrılar arasına bekleme konur.
func search(query: String, near coordinate: CLLocationCoordinate2D) -> [MKMapItem] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.region = MKCoordinateRegion(
        center: coordinate,
        latitudinalMeters: 8_000, longitudinalMeters: 8_000
    )
    var items: [MKMapItem] = []
    var done = false
    MKLocalSearch(request: request).start { response, _ in
        items = response?.mapItems ?? []
        done = true
    }
    while !done {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }
    return items
}

var failCount = 0
var nearCount = 0

for route in catalog.routes {
    let title = route.name["tr"] ?? route.id
    print("\n━━ \(route.id) — \(title) (verified: \(route.verified))")

    for (index, place) in route.places.enumerated() {
        let claimed = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        let items = search(query: "\(place.name), \(catalog.city)", near: claimed)
        Thread.sleep(forTimeInterval: 1.0)

        guard !items.isEmpty else {
            print("  FAIL  \(place.name): MKLocalSearch sonuç YOK (halüsinasyon şüphesi)")
            failCount += 1
            continue
        }
        let best = items
            .map { (item: $0, dist: distanceMeters(claimed, $0.placemark.coordinate)) }
            .min { $0.dist < $1.dist }!

        let label: String
        switch best.dist {
        case ..<250: label = "PASS "
        case ..<1_000: label = "NEAR "; nearCount += 1
        default: label = "FAIL "; failCount += 1
        }
        let matched = best.item.name ?? "?"
        print("  \(label) \(place.name): en yakın eşleşme \"\(matched)\" — \(Int(best.dist)) m")

        if index > 0 {
            let previous = route.places[index - 1]
            let legMeters = distanceMeters(
                CLLocationCoordinate2D(latitude: previous.latitude, longitude: previous.longitude),
                claimed
            )
            if legMeters > 2_500 {
                print("  UYARI \(previous.name) → \(place.name): \(Int(legMeters)) m (kuş uçuşu > 2.5 km, yürüme kuralı)")
            }
        }
    }
}

print("\nÖZET: FAIL=\(failCount)  NEAR=\(nearCount)  (NEAR'lar elle kontrol ister)")
exit(failCount > 0 ? 1 : 0)
