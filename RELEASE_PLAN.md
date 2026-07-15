# RELEASE_PLAN.md — TestFlight'a Giden Yol + UX Büyütme (2026-07-15)

> Kullanıcı kararları: **önce TestFlight beta** (RevenueCat beta sırasında yapılacak),
> crash/analytics **Firebase Crashlytics + Analytics**, UX önceliği **dördü birden**
> (Yakınımda, fotoğraf, Keşfet, liste kolaylıkları). **Stitch + Claude Code design
> bağlantısı EN SON** — tüm fazlar bitince.
> İlerleme kutucuklarla işaretlenir. Faz başına tek commit kuralı geçerli.

---

## FAZ 0 — Build'i yeşile çek (yarım kalan AdMob/UMP işi)
- [x] 0.1 **(Kullanıcı, Xcode)** `GoogleUserMessagingPlatform` ürünü Pinly target'ına linklendi
- [x] 0.2 Simülatör build yeşil — `ConsentManager.swift` derleniyor (2026-07-15)
- [ ] 0.3 Gerçek cihazda smoke test: açılışta ATT diyaloğu çıkıyor, rota tamamlayınca
      interstitial geliyor (gerçek ID'de "no fill" olabilir — hata değil)

## FAZ 1 — Firebase Crashlytics + Analytics
- [x] 1.1 **(Kullanıcı)** Firebase Console'da proje oluşturuldu (`pinly-5aa6e`) →
      `GoogleService-Info.plist` `Pinly/` klasörüne kondu (bundle ID `com.farad.pinly` doğrulandı)
- [x] 1.2 **(Kullanıcı, Xcode)** SPM: `firebase-ios-sdk` eklendi, FirebaseAnalytics + FirebaseCrashlytics
      ürünleri Pinly target'ına linklendi
- [x] 1.3 `PinlyApp.init()`: `FirebaseApp.configure()` en erken noktada (ConsentManager/AdMob akışını
      beklemez — Analytics rıza gerektirmez, ATT sonrası IDFA erişimi otomatik düzelir).
      `FirebaseAnalyticsService: AnalyticsTracking` yazıldı, composition root artık bunu kullanıyor
      (`NoOpAnalyticsService` sadece testlerde/preview'larda kalıyor — ViewModel default'ları değişmedi)
- [x] 1.4 **(Kullanıcı, Xcode)** Crashlytics dSYM upload Run Script fazı eklendi. Script ilk çalıştırmada
      "Could not get GOOGLE_APP_ID" hatası verdi — kök neden Xcode 15+'ın **User Script Sandboxing**'i
      (`ENABLE_USER_SCRIPT_SANDBOXING`), script'in `GoogleService-Info.plist`'e erişimini engelliyordu.
      Firebase'in bilinen/dokümante ettiği sorun; proje genelinde (PBXProject Debug+Release) bu ayar
      `NO`'ya çekildi, build+testler tekrar yeşil.
- [x] 1.5 Temel event seti (protokol arkasında, `AnalyticsTracking` + `\.analytics` environment key):
      `place_added` (kaynak: manual/qr/deeplink/swarm/nearby/quick_add/route_import), `route_started`,
      `route_completed`, `route_shared`, `paywall_shown`, `nearby_search`.
      Şimdilik `NoOpAnalyticsService` (DEBUG'da konsola yazar) — Firebase gelince (1.2-1.3)
      sadece somut sınıf değişir, çağıran yerler sabit
- [ ] 1.6 MetricKit tanılama ekranı kalıyor (yerinde duruyor, çakışma yok)

## FAZ 2 — Yakınımda: kategori bug'ı fix + güçlendirme
> **Kök neden** (`GeocodingService.swift:44,61`): MKLocalSearch'e sadece
> `naturalLanguageQuery = category.localizedName` veriliyor ve dönen HER sonuç seçili
> kategoriyle damgalanıyor. "Park" metin araması adında "park" geçen restoranı da getirir;
> MapKit'in gerçek `pointOfInterestCategory` alanı hiç okunmuyor.
- [x] 2.1 `PlaceCategory → MKPointOfInterestCategory` eşlemesi + `request.pointOfInterestFilter`:
      restaurant→.restaurant, cafe→.cafe, park→.park+.nationalPark, museum→.museum,
      library→.library, dessert→.bakery. `historical`/`general` için POI karşılığı yok (iOS 17) →
      metin sorgusu kalır ama sonuçta `item.pointOfInterestCategory` uyumsuzsa (örn. restaurant
      dönen "tarihi yer" sonucu) elenir/gerçek kategorisine çevrilir.
- [x] 2.2 Sonuç doğrulama: `item.pointOfInterestCategory` varsa gösterilen kategoriyi ONDAN türet,
      damgalama yerine. Eşleşmeyen sonuçlar listeden düşür.
- [x] 2.3 Mesafe: her satırda kullanıcı konumuna uzaklık (m/km) + uzaklığa göre sıralama
- [x] 2.4 Yarıçap seçici (500 m / 1 km / 2 km / 5 km — `@AppStorage`, rota akışındaki
      `searchRadiusKm` ile ayrı anahtar)
- [x] 2.5 Sonuçları mini haritada görme (toggle: liste ⇄ harita, mevcut NavigationMapView
      DEĞİL — basit `Map` yeterli)
- [x] 2.6 Unit test: mock NearbySearching ile kategori doğrulama + sıralama testleri
- [x] 2.7 10 sonuç limitini 25'e çıkar (MKLocalSearch zaten az döndürüyor, prefix gevşesin)

## FAZ 3 — Mekanlara fotoğraf
> Görsellik şu an sıfır. Foursquare'in yerini hedefleyen uygulama için en büyük UX eksiği.
- [x] 3.1 `Place` modeline `photoFileName: String?` (SwiftData lightweight migration —
      yeni optional alan, sorunsuz). Foto dosyası `Documents/PlacePhotos/<uuid>.jpg`
      (profil fotoğrafı deseniyle aynı: 1200px uzun kenar, 0.8 JPEG)
- [x] 3.2 `PlacePhotoStoring` protokolü + servis (kaydet/yükle/sil; Place silinince dosya da silinir)
- [x] 3.3 AddPlaceView + EditPlaceView: PhotosPicker (galeri) + kamera seçeneği (`CameraPicker`,
      simülatörde kamera butonu gizli; NSCameraUsageDescription metni foto çekimini de kapsıyor)
- [x] 3.4 PlaceDetailView: foto başlık görseli; PlacesListView satırında thumbnail
      (Keşfet kartları FAZ 4 yeniden tasarımında ele alınacak)
- [x] 3.5 RouteShareCard (Instagram kartı): durak fotoğraflarından en fazla 3'lü kolaj şeridi
- [x] 3.6 QR/link paylaşımına foto DAHİL DEĞİL (URL şişer) — bilinçli karar

## FAZ 4 — Keşfet'i gerçek keşfe çevir
> Şu an "Keşfet" sadece kendi eklediğin mekanları kategori grid'inde gösteriyor —
> keşif değil, koleksiyon. Yakınımda tek gerçek keşif aracı ve bir kart arkasında gömülü.
- [x] 4.1 Bilgi mimarisi: Keşfet'in ana içeriği harita — tüm mekanlar pin (ziyaret edilenler
      soluk), "Gitmediklerim" + kategori filtre chip'leri üstte, pin'e dokun → PlaceDetailView
- [x] 4.2 Yakınımda yatay öneri şeridi panelin en üstünde (konuma göre 5 öneri, seçili
      kategoriye duyarlı, "Tümünü Gör" → NearbyPlacesView, Ekle butonu freemium gate'li)
- [x] 4.3 Kategori grid'i "Koleksiyonum" bölümü olarak panelde aşağıda
- [x] 4.4 Hazır rotalar Keşfet panelinde yatay mini kartlar ("Rotalarıma Ekle";
      SavedRoutesView boş ekran kartları da yerinde duruyor)
- [x] 4.5 Tasarım kararı kullanıcıyla alındı (2026-07-15): tam ekran harita + çekilebilir
      alt panel (Apple Maps deseni; collapsed/half/expanded üç durak, custom drag)

## FAZ 5 — Liste/işlem kolaylıkları (birikmiş küçük işler)
- [x] 5.1 Toplu mekan silme: PlacesListView edit modu + multi-select + onay diyaloğu
      (sıralama menüsünde "Mekanları Seç", toplu silmede fotoğraflar da temizlenir)
- [x] 5.2 `SavedPlaceSnapshot.placeId: UUID?` — isimle eşleşme kırılganlığının kalıcı çözümü
      (nil ise eski davranış: isimle eşleş; migration gerekmez, Codable optional alan.
      Yazan yerler: SavedRouteManager + PlanRouteViewModel; okuyanlar: SavedRoutesViewModel
      loadAndStart + PlanRouteViewModel hydrateIfEditing. İçe aktarılan/hazır rotalarda nil kalır)
- [x] 5.3 Rota paylaşım önizlemesi: RouteSharePickerView'e mini harita + numaralı durak listesi
- [x] 5.4 Bildirim izni onboarding'den Haftalık Rapor ekranına taşındı: `scheduleWeeklyNotification`
      artık izin istemez (verilmişse planlar), yeni `requestWeeklyNotification` CTA kartından
      (`pinly.weeklyNotifOptIn`) izni ister

## FAZ 6 — TestFlight beta
- [x] 6.1 Pro/paywall gizleme feature flag'i: `FeatureFlags.unlimitedPlacesInBeta` —
      Release + sandbox receipt (gerçek TestFlight) build'inde `canAddPlace` hep true,
      7 gate noktası hiç tetiklenmez. DEBUG'da bilinçli olarak kapalı (geliştirme +
      unit testlerde freemium normal çalışır). Protokol imzası değişmedi.
- [ ] 6.2 App Store Connect: app kaydı, bundle ID, App Privacy formu (konum, foto,
      AdMob/Firebase veri bildirimleri — ATT'yi beyan et)
- [ ] 6.3 Archive + upload, internal test grubu, beta davetleri
- [ ] 6.4 Beta sırasında paralel: RevenueCat entegrasyonu (App Store Connect ürünleri
      `pinly_pro_monthly` $4.99 / `pinly_pro_yearly` $39.99 + `RevenueCatEntitlementService`
      + PaywallView gerçek purchase/restore)

## FAZ 7 — Stitch + Claude Code design bağlantısı (EN SON)
- [ ] 7.1 Stitch ile UI tasarım akışı kur, Claude Code design sync bağlantısı
- [ ] 7.2 Tasarım sistemini (Theme.swift) Stitch çıktılarıyla hizala

---

## Bilinen dış bağımlılıklar (kullanıcının yapacakları)
1. ~~FAZ 0.1 — Xcode'da UMP ürün linki~~ ✔ yapıldı (2026-07-15)
2. FAZ 0.3 — Gerçek cihazda ATT + interstitial smoke testi
3. FAZ 1.1 — Firebase Console projesi + GoogleService-Info.plist
4. FAZ 6.2 — App Store Connect app kaydı (Apple Developer hesabı hazır)
5. FAZ 6.4 — RevenueCat hesabı + API key
