# FAZ 2 — Bug Turu Spec'i (Sonnet uygular, Fable review eder)

## 1. Yakınımda yarıçap bug'ı ("3/5 km çalışmıyor, hep ~1 km")

**Kök neden A (kesin):** `GeocodingService.swift` metin arama dalında
`MKCoordinateRegion(center:latitudinalMeters:longitudinalMeters:)` parametreleri TOPLAM span ister;
`radiusMeters` verilince etkin yarıçap yarıya iner. → `radiusMeters * 2` yap (iki parametre de).

**Kök neden B (algısal):** sonuç `sorted{distance}.prefix(25)` — yoğun bölgede en yakın 25 sonuç
zaten ilk ~1 km'de; yarıçap büyütmek listeyi DEĞİŞTİRMİYOR. **Fable kararı — bant çeşitlendirme:**
```
yarıçap ≤ 1 km  → mevcut davranış (en yakın 25)
yarıçap  > 1 km → sonuçları 3 banda ayır: [0, r/3), [r/3, 2r/3), [2r/3, r]
                  bantlardan sırayla (round-robin) al, her bant kendi içinde mesafe sıralı,
                  toplam 25; bir bant boşsa kalanlar diğerlerinden dolar.
```
- Saf fonksiyon olarak yaz: `NearbyResultBander.diversify(_ places: [NearbyPlace], radius: Double) -> [NearbyPlace]`
  (birim test: tek bantlı küme, boş bant, 25 üstü kırpım, sıra kararlılığı).
- `DefaultNearbySearchService.searchNearby` sonunda `prefix(25)` yerine bunu çağır.
- UI: NearbyPlacesView listesi zaten mesafe gösteriyor; ekstra değişiklik yok.
- **Doğrulama:** XcodeBuildMCP simülatör konum simülasyonu (Taksim 41.0370, 28.9850) → 1/3/5 km'de
  sonuç kümelerinin gerçekten farklılaştığını ve 5 km'de >3 km sonuç içerdiğini ekran görüntüsüyle kanıtla.

## 2. Koordinatsız mekan rota hizasını kaydırıyor (Fable algoritma tasarımı)

`RouteManager.calculateRoutes` şu an `allCoords += routePlaces.compactMap { $0.coordinate }` —
koordinatsız mekan ARADAN DÜŞÜNCE segment[i] ↔ durak[i] eşleşmesi bozuluyor (2026-07-23'te
eklenen nil-user placeholder fix'iyle AYNI sınıf hata, farklı tetikleyici).

**Algoritma (birebir uygula):**
```
cursor: CLLocationCoordinate2D? = userLocation        // nil olabilir
segmentPlan: [(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)?] = []
for place in routePlaces:
    if let dest = place.coordinate:
        segmentPlan.append(cursor.map { (from: $0, to: dest) })   // cursor nil → placeholder
        cursor = dest
    else:
        segmentPlan.append(nil)                                    // hedefi bilinmeyen bacak
```
- `segmentPlan.count == routePlaces.count` HER ZAMAN (invariant — test et).
- nil planlar MKDirections'a gitmez; polyline/steps/distance boş placeholder alır.
- `failedLegCount` = SADECE "planlanıp hesaplanamayan" (nil plan sayılmaz; onun için ayrı
  `unroutableStopCount` → RouteSummaryView'de farklı uyarı metni: "Bazı durakların konumu yok").
- Mevcut nil-user placeholder insert'i bu döngünün doğal sonucu olur (ilk durakta cursor nil) —
  özel insert kodu SİLİNİR, davranış aynı kalır (RouteManagerAlignmentTests yeşil kalmalı).
- Yeni testler: ortada koordinatsız durak → dizi uzunlukları eşit + sonraki segment DOĞRU çifte
  bağlanıyor (önceki koordinatlıdan sonraki koordinatlıya).

## 3. PlanRouteView düzenleme modunda isimle eşleşme → placeId

- `SavedRoutesView.loadAndStart` zaten id-öncelikli eşliyor; aynı mantık `PlanRouteView`
  editingRoute yolunda YOK. Ortak çözücüye çıkar:
  `SnapshotPlaceResolver.resolve(_ snapshot: SavedPlaceSnapshot, in places: [Place]) -> Place?`
  (id eşleşmesi → isim fallback; saf, test edilebilir; `SavedRouteManager.swift` içine static).
- İki call site de bunu kullanır; davranış farkı testle sabitlenir.

## 4. Build 4 — DURUM (Sonnet, 2026-07-23)
- [x] Tüm testler + yukarıdaki yeni testler yeşil (134/134 — 13 yeni test)
- [x] Sürüm 1.0 build 4 (Xcode proje ayarları güncellendi)
- [ ] **TestFlight'a fiili yükleme YAPILMADI** — archive/imzalama Organizer erişimi ister,
      Ferhat'ın Xcode'dan yapması ya da onayı gerekiyor
- [x] Beta notları hazır (aşağıda)

### Beta Notları (TestFlight "What to Test")
**TR:** Bu sürümde: (1) Rota oluştururken artık aynı kategoriden birden fazla mekan seçebilirsin
(ör. 2 farklı kafe); (2) Yakınımda'da 3/5 km yarıçap seçenekleri artık gerçekten farklı sonuçlar
gösteriyor; (3) Navigasyon talimatlarının zamanlaması iyileştirildi (adım tamamlanma algısı daha
isabetli); (4) Koordinatı olmayan mekanlar rotaya girdiğinde artık uyarı gösteriliyor, rota
kaymıyor. Geri bildirimlerinizi bekliyoruz!

**EN:** In this build: (1) You can now select more than one place per category when building a
route (e.g. 2 different cafés); (2) The 3/5 km radius options in Nearby now actually return
different results; (3) Navigation instruction timing is more accurate; (4) Places without a
location no longer shift the route silently — you'll see a warning instead. Feedback welcome!

**Not (kod denetimi gerekiyor, önce yapılmalı — TestFlight'a yüklemeden ÖNCE):**
- [ ] Fable review kapısı: `/code-review` + bant çeşitlendirme ve segment invariant'ının elle
      denetimi. RouteManager'a `routePlaces` dışında yeni @Published EKLENMEYECEK kuralı: bu turda
      `unroutableStopCount` eklendi (spec'te açıkça istenmişti — "Bazı durakların konumu yok" ayrı
      uyarı metni için); Fable bu istisnayı review'da onaylamalı.
- [ ] XcodeBuildMCP ile simülatörde gerçek konum simülasyonu + 1/3/5 km ekran görüntüsü doğrulaması
      henüz YAPILMADI — sadece birim testlerle doğrulandı.
