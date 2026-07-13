# Pinly — Proje Bağlamı

## Proje Nedir
iOS SwiftUI uygulaması. Mekan kaydetme + yürüyüş rotası planlama + turn-by-turn navigasyon.
Foursquare City Guide Aralık 2024'te kapandı — Türkiye global trafiğin %9'unu oluşturuyordu.
Bu boşluğu doldurmak için konumlanmış. Türkiye + turist odaklı, ilerleyen süreçte MENA/Balkanlar.

## Hedef
Freemium model, $4.99/ay Pro. 18 ayda 100K kullanıcı → $8-15K/ay gelir.

> İlgili belgeler: `ROADMAP.md` (ürün/büyüme planı + test stratejisi), `IMPROVEMENT_PLAN.md` (kod incelemesi bulguları, düzeltilen buglar B1-B15, refactor geçmişi), `MASTER_PLAN.md` (2026-07-13 hijyen+mimari temizlik operasyonu — isimlendirme, test target'ı, bug fix'ler, refactorlar; ilerleme kutucuklarla takip edilir).

## Teknik Stack
- SwiftUI + SwiftData (iOS 17+)
- MapKit (MKDirections yürüyüş rotası, MKMapView UIViewRepresentable + yeni Map API karışık)
- ActivityKit (Live Activity kilit ekranı + Dynamic Island), WidgetKit (Hızlı Ekle widget'ı)
- HealthKit (adım + mesafe), AVFoundation (QR tarama), CoreImage (QR üretme)
- GoogleMobileAds (interstitial — şu an TEST ID'leri)
- Deep link: `pinly://` scheme (eski `notiongo://` backwards compat)
- Xcode projesi: `Pinly.xcodeproj` — target'lar: `Pinly` (app), `PinlyLiveActivityExtension` (widget extension, kaynak klasörü `PinlyLiveActivity/`), `PinlyTests` (unit test bundle, `MASTER_PLAN.md` Faz 3)

## SourceKit Uyarıları Hakkında
SourceKit "Cannot find X in scope" hataları FALSE POSITIVE'dir.
SourceKit'in Xcode build context'i yoktur. Xcode'da compile edilir, sorun yoktur.
Bu hatalar için kod değiştirme.

---

# MİMARİ

**MVVM + protokol tabanlı servis katmanı.** Composition root `PinlyApp`; servisler SwiftUI Environment üzerinden inject edilir. Eski static `FreemiumManager` ve `BadgeManager` SİLİNDİ — asla referans verme.

```
PinlyApp (composition root)
  ├─ .modelContainer([Place, RouteHistory, SavedRoute])   ← SwiftData
  ├─ .environment(\.entitlements, LocalEntitlementService.shared)  ← EntitlementProviding
  ├─ .environment(\.badges,       DefaultBadgeService.shared)      ← BadgeServicing
  ├─ .environment(\.ads,          AdManager.shared)                ← AdPresenting
  └─ .environmentObject(LanguageManager)
       ContentView
         ├─ OnboardingView (ilk açılış, pinly.hasSeenOnboarding)
         ├─ PermissionView / LocationDeniedView (konum izni durumuna göre)
         └─ HomeView (TabView) — PlaceStore, LocationManager, RouteManager
              burada @StateObject olarak yaşar ve environmentObject ile dağıtılır
```

## Katmanlar

### `Pinly/Services/` — Protokol tabanlı servisler (DIP)
| Dosya | İçerik |
|---|---|
| `ServiceEnvironment.swift` | `\.entitlements`, `\.badges`, `\.ads`, `\.geocoding`, `\.healthStats`, `\.savedRoutes`, `\.routeURLCoding`, `\.swarmImporting`, `\.routeExporting`, `\.weeklyStats`, `\.notificationScheduling`, `\.qrCodeGenerator` EnvironmentKey'leri. Default value'lar gerçek singleton'lar → preview'lar kurulum istemez, testte mock inject edilir. |
| `EntitlementService.swift` | `EntitlementProviding` (isPro get/set, freeLimit=20, `canAddPlace(currentCount:)`) + `LocalEntitlementService`: UserDefaults `pinly.isPro` (+ `notiongo.isPro`'dan migrasyon). RevenueCat gelince SADECE bu sınıf değişecek, call site'lar sabit. |
| `BadgeService.swift` | `BadgeServicing` + `DefaultBadgeService`: 21 rozetin kilit mantığı (`check(placeStore:)` yeni açılanları döndürür), sayaçlar UserDefaults'ta (`pinly.completedRoutes`, `pinly.sharedRoutes`, `pinly.savedRoutes`, `pinly.consecutiveDays`, sabah/gece rota bayrakları). `recordAppOpen()` gün serisini hesaplar. |
| `AdService.swift` | `AdPresenting` protokolü: `showInterstitialIfNeeded(then:)` — Pro'ya veya reklam hazır değilse completion hemen çalışır. |
| `GeocodingService.swift` | `GeocodingProviding`: `forwardGeocode(query:)` / `reverseGeocode(coordinate:)`. `DefaultGeocodingService` MKLocalSearch + CLGeocoder sarmalıyor; testte mock enjekte edilir. |
| `HealthKitService.swift` | `HealthStatsProviding`: `requestAuthorization()` + `fetchRouteStats(from:to:)` (adım+mesafe). |
| `QRCodeGenerating.swift` | `QRCodeGenerating` protokolü: CoreImage tabanlı QR üretimi (`SharePlaceView`'de kullanılır). |

### `Pinly/Managers/` — ObservableObject state yöneticileri
| Dosya | Rol |
|---|---|
| `PlaceStore.swift` | Place CRUD + `@Published places`. `addPlace` koordinat verilmezse MKLocalSearch ile geocode eder (isim+adres, sonra sadece adres fallback). `refreshBadges()` → `pendingBadges` kuyruğu → HomeView'de `BadgeBannerView`. `places(category:userLocation:radiusKm:)` kategori+yarıçap filtresi (rota akışında kullanılır; radiusKm 0 = sınırsız). |
| `RouteManager.swift` | **Navigasyonun beyni.** @MainActor. Rota verisi: `routePolylines`/`stepsPerSegment`/`segmentDistances` — hepsi `routePlaces` ile indeks hizalı; **başarısız segment boş placeholder alır, compactMap'le düşürme (bug B1)**. `setRoute(places:name:)` kategori akışını atlayan çağıranlar için (tek mekan, kayıtlı rota). `calculateRoutes` paralel MKDirections (TaskGroup). `updateNavigation`: 30 m durak varışı → ara durakta `isPausedAtStop`, son durakta `completeRoute`; adım ilerletme 20 m eşiği; rotadan sapma >75 m → 10 sn cooldown'lu yeniden hesaplama. Live Activity'yi başlatır/günceller/bitirir. |
| `LocationManager.swift` | İzin `requestPermission()` ile ONBOARDING SONRASI istenir (init'te değil). Normalde tek seferlik konum (100 m doğruluk, pil dostu) + reverse geocode → `currentDistrict`. `startNavigationTracking()`: 10 m doğruluk/filtre + 2 saat güvenlik timer'ı. |
| `SavedRouteManager.swift` | Static yardımcılar: `save` (merkez = koordinat ortalaması, koordinat yoksa İstanbul default — (0,0) yazma, bug B10), `distanceKm` (uzaklık uyarısı), `delete`. |
| `LanguageManager.swift` | Uygulama içi dil değiştirme: Bundle swizzle (`BundleEx.localizedString`) + `pinly.appLanguage`. `refreshID` değişince HomeView `.id()` ile yeniden kurulur. Diller: tr/en/es/de/ru. |
| `WeeklyReportManager.swift` | `WeeklyStats` hesabı (son 7 gün RouteHistory + tüm mekanlardan top kategori/ilçe) + Pazar 09:00 tekrarlı lokal bildirim. |
| `AdManager.swift` | `AdPresenting` somut implementasyonu; AdMob interstitial, entitlements constructor-injected. TEST ID kullanıyor (yayın öncesi değişmeli). |

### `Pinly/Models/` — Veri modelleri
| Dosya | İçerik |
|---|---|
| `Place.swift` | @Model: name, category (String!), address, notes, isVisited, visitCount, userRating(1-5), lat/lon optional, createdAt. `PlaceCategory` enum (8 kategori, renk+ikon). **DB'de eski Türkçe kategori string'leri var → daima `PlaceCategory.from(_:)` kullan, `init(rawValue:)` değil.** |
| `SavedRoute.swift` | @Model: önceden planlanmış rota. Mekanlar `SavedPlaceSnapshot` (Codable) olarak JSON `Data` içinde — Place silinse de rota bozulmaz. `centerLatitude/Longitude` uzaklık uyarısı + thumbnail için. `isPublic`/`supabaseId` sosyal faz için hazır, kullanılmıyor. |
| `RouteHistory.swift` | @Model: tamamlanan rota kaydı (placeNames kopya olarak, mesafe/süre/adım/kategori). |
| `Badge.swift` | 21 rozetlik enum: başlık/açıklama lokalize key'lerden, ikon+renk, `progressText(placeStore:badges:)` kilitli rozet ilerlemesi. Kilit MANTIĞI `DefaultBadgeService.check`'te. |
| `PlaceImporter.swift` | Tüm import/export tek yerde: tek mekan URL build/parse (`pinly://addplace?...`), rota URL (`pinly://route?data=<base64 JSON>`; yeni format `{places,name,category}` + eski düz array kabul), Swarm `checkins.json` parse (venue ID tekilleştirme, Foursquare kategori eşlemesi), GPX/PDF export (dosya adı sanitize edilir — bug B9), `save(_:placeStore:context:)` ortak import kaydı (koordinat varsa geocode atlanır). `RouteCategory` enum (Şehir İçi/Şehir Dışı/Yurt Dışı) burada. |
| `PinlyActivityAttributes.swift` | Live Activity ContentState (talimat, kalan mesafe, durak x/y, tamamlanma %). **Her iki target'a da ekli olmalı** (`Pinly.xcodeproj/project.pbxproj`'daki `PBXFileSystemSynchronizedBuildFileExceptionSet` ile `PinlyLiveActivityExtension` target'ına açıkça eklenmiş — klasör yeniden adlandırılırsa bu exception'ın yolu da elle güncellenmeli). |
| `UserProfile.swift` | Codable struct: firstName/lastName/birthYear + `age`/`fullName`/`initials`. Kalıcılık `Pinly/Services/ProfileService.swift` üzerinden (`ProfileProviding`, `pinly.userProfile` UserDefaults key + `Documents/profile_photo.jpg`). |

### `Pinly/Design/` — Tasarım sistemi
`Theme.swift`: iki tema — **slate** (koyu/mavi, dinamik) ve **lavender** (temiz lavanta-beyaz, indigo aksan; eski kod adı "farad" idi, UserDefaults migrasyonuyla yeniden adlandırıldı). `PinlyTheme.primary` (dark'ta açılır), kısık gül `accent`, `gold`/`slate` destek, `ground`/`surface` her iki temada da tanımlı. `navy` (#1B2733) tab bar + paylaşım kartı gibi her modda koyu yüzeyler için sabit. `PinlyPrimaryButtonStyle`, `PinlySecondaryButtonStyle`, `.pinlyCard()` (gölge yerine ince kontur), `StatChip`. **Yeni bileşenler renkleri BURADAN alır, hardcode etme.** Yeşil YOK — kullanıcı kararı.
`ThemeManager.swift`: `ThemeStyle` enum (`.slate`/`.lavender`) + `pinly.theme` UserDefaults anahtarı; `ContentView`'daki `.id(themeManager.themeKey)` tema değişince kökü yeniden kurar.

### `Pinly/Views/` — Ekranlar

**Kök & sekmeler:**
- `ContentView.swift` — onboarding/profil kurulumu/izin/ana yönlendirme; deep link handler (`addplace` → ImportConfirmView, `route` → RouteImportView, `navigation` → HomeView'e bırakılır); import'larda freemium gate.
- `Views/home/HomeView.swift` — 4 sekmeli TabView + rozet banner overlay + `pinly://navigation` ve `pinly://quickadd` handler'ları.
- `Views/home/MainTab.swift` — Ana sekme: selamlama, StatChip şeridi, hero "Rota Planla" (→MapView), 4 hızlı aksiyon (Mekanlarım/Mekan Ekle/QR Tara/Rota Tasarla), Son Eklenenler (illüstrasyonlu kartlar).
- `DiscoverView.swift` — Keşfet: kategori grid → `CategoryPlacesView` (Gidilecek/Ziyaret Edildi bölümleri).
- `SavedRoutesView.swift` — Rotalar sekmesi: @Query ile SavedRoute listesi, harita thumbnail'li kartlar, >1 km uzaklık uyarısı, swipe Düzenle/Sil. `loadAndStart`: snapshot'ları İSİMLE Place'e eşler (bulunamazsa koordinatlı geçici Place), `routeManager.setRoute` → RouteSummaryView fullScreenCover.
- `Views/home/ProfileTab.swift` (`struct ProfileTab`) — Profil sekmesi: avatar+isim+mini istatistikler, tema seçici (Slate/Lavanta), görünüm (light/dark/system), İstatistiklerim/Geçmiş/Haftalık Rapor/Rozetler/Dil seçici.
- `ProfileSetupView.swift` — onboarding sonrası tek seferlik ad/soyad/doğum yılı formu (`pinly.hasSetupProfile`); `ProfileView.swift` — profil düzenleme.

**Mekan CRUD:**
- `Views/home/PlacesListView.swift` + `PlacesListViewModel.swift` — liste; arama/kategori chip/sıralama mantığı ViewModel'de (saf fonksiyonlar, test edilebilir; sıralama tercihi `pinly.sortOption`). Toolbar: sırala/Swarm import (fileImporter)/QR/ekle(gate). Swipe: sil+paylaş / ziyaret toggle.
- `AddPlaceView.swift` / `EditPlaceView.swift` (+ `AddPlaceViewModel`/`EditPlaceViewModel`/`PlaceFormViewModel`/`PlaceFormComponents.swift`) — form; 3 konum yöntemi: adres yaz (geocode), mevcut konum, **Haritada Pinle** → `MapPinPickerView.swift` + `MapPinPickerViewModel.swift` (sabit merkez pin, harita altında kayar, kamera durunca reverse geocode — Uber deseni).
- `PlaceDetailView.swift` — salt okunur detay + harita önizleme + Düzenle/Paylaş.
- `QuickAddSheet.swift` + `QuickAddViewModel.swift` — widget deep link'inden hızlı ekleme (konum otomatik).
- `SharePlaceView.swift` — QR üretimi (CoreImage) + ShareLink. `QRScannerView.swift` + `QRScannerViewModel.swift` — AVFoundation tarama + `ImportConfirmView` + freemium gate.

**ViewModel katmanı:** Çoğu ekranın state/iş mantığı ayrı `@MainActor final class ...ViewModel: ObservableObject` dosyasında (`AddPlaceViewModel`, `EditPlaceViewModel`, `MapViewModel`, `MapPinPickerViewModel`, `PlanRouteViewModel`, `RouteSummaryViewModel`, `PlacePickerStepViewModel`, `QuickAddViewModel`, `QRScannerViewModel`, `SavedRoutesViewModel`, `MainTabViewModel`, `PlaceFormViewModel`). Desen: stateful/oturuma-özel bağımlılıklar (RouteManager, PlaceStore, ModelContext) constructor'da tutulmaz — metodlara parametre geçirilir; sadece varsayılan singleton'ı olan servisler (badges/entitlements/ads/geocoding/healthStats/savedRoutes/routeExporter) constructor injection ile alınır. Bu sayede mock'larla test edilebilirler (bkz. `PinlyTests/`).

**Rota akışı 1 — anlık rota (MapView'den):**
```
MapView (tüm mekanlar MKMapView'de; pin'e dokun → PlaceCard: Navigate Here/düzenle/sil)
  └─ "Rota Oluştur" → CategoryPickerView (kategori çoklu seç)
       → CategoryOrderingView (sürükle sırala)
       → PlacePickerStepView (kategori başına 1 mekan, yarıçap filtresi @AppStorage searchRadiusKm, recursive navigationDestination)
       → RouteSummaryView
```
`routeManager.selectedCategories` bu akışta gerçek kategori adları; `setRoute` ile kurulunca `"i_uuid"` sentetik key'ler. `routePlaces` her iki durumda `selectedPlaces` dict'inden sıralı çözülür.

**Rota akışı 2 — önceden planla:** `PlanRouteView.swift` (3 adım: MapReader pin bırak → pine mesafeyle sıralı mekan çoklu seç → isim+kategori) → SavedRoute yazar. `editingRoute` parametresiyle düzenleme modu (snapshot eşleşmesi İSİMLE — kırılgan, bilinen sorun).

**`RouteSummaryView.swift` — navigasyon merkezi:** harita (`NavigationMapView`) + durak listesi + alt buton alanı. Navigasyon öncesi: Linki Paylaş (interstitial→`RouteSharePickerView`), Rotayı Kaydet (`SaveRouteSheet`), GPX/PDF (Pro gate), Navigasyonu Başlat (badge `recordRouteStarted` + HealthKit izni + Live Activity). Navigasyonda: `NavigationBanner` (talimat+ilerleme), durakta duraklama → not ekleme + puanlama (`RatingSheetView`) + "Sonraki Durağa Git". Tamamlanınca: badge/history/HealthKit kaydı → interstitial → `RouteCompletionOverlay` → `RouteShareCard.swift` (ImageRenderer ile 1080×1350 Instagram kartı).

**`\.dismissRouteFlow` environment key'i (MapView.swift'te tanımlı):** RouteSummaryView'i sunan HER fullScreenCover bunu set ETMELİ (MapView tek mekan, SavedRoutesView, HomeView deep link) — yoksa X butonu ve tamamlama overlay'i no-op olur, kullanıcı ekranda kilitli kalır (bug B5).

- `NavigationMapView.swift` — UIViewRepresentable; navigasyonda `.follow` tracking, değilse region yalnızca DEĞİŞİNCE set edilir (B2); overlay/annotation yalnızca içerik değişince yeniden kurulur (B3/B4); tamamlanan segmentler yeşil çizilir; sonraki durakta pulse animasyonlu annotation.

**Diğer:** `OnboardingView.swift` (3 sayfa; bitince konum izni + haftalık bildirim), `PaywallView.swift` (**bilinçli placeholder** — "Pro'ya Geç" ödemesiz isPro=true yapar; RevenueCat TODO'ları içinde), `BadgesView.swift` (grid + kilitli ilerleme + `BadgeBannerView`), `RouteHistoryView.swift`, `WeeklyReportView.swift`, `ProfileStatsView.swift`, `view/home/ImportViews.swift` (RouteImportView: Tümünü Ekle / Kayıtlı Rotalarıma Ekle; SwarmImportView: 50 mekan önizleme + gate), `view/home/StatusViews.swift` (izin ekranları).

### `PinlyLiveActivity/` — Widget extension
- `PinlyLiveActivityBundle.swift` — @main: `PinlyLiveActivityWidget` + `QuickAddWidget` kayıtlı.
- `PinlyLiveActivityView.swift` — GERÇEK Live Activity: kilit ekranı (talimat, durak x/y, ilerleme, `pinly://navigation` "Navigasyona Dön" butonu) + Dynamic Island.
- `QuickAddWidget.swift` — small/medium statik widget, `pinly://quickadd` → QuickAddSheet (App Groups gerekmez).

## Veri Akışı Özeti
- **Kalıcılık:** SwiftData (Place/SavedRoute/RouteHistory) + UserDefaults (isPro, rozetler+sayaçlar, dil, onboarding, sıralama, yarıçap).
- **Freemium gate noktaları (7):** MainTab "Mekan Ekle", PlacesListView +, MapView +, QRScannerView import, deep link tek mekan, rota import, Swarm import, QuickAddSheet. Hepsi `entitlements.canAddPlace` → PaywallView. Pro gate: GPX/PDF export. Reklam: rota tamamlama + link paylaşımı öncesi interstitial (Pro'ya gösterilmez).
- **Rozet döngüsü:** olay → `badges.record*()` → `check(placeStore:)` → yeni rozetler `placeStore.pendingBadges` → HomeView banner (3 sn).
- **Deep linkler:** `pinly://addplace?name=..&lat=..` | `pinly://route?data=<base64>` | `pinly://navigation` | `pinly://quickadd`.

## Bilinen Kırılganlıklar
- SavedRoute snapshot ↔ Place eşleşmesi isimle → mekan yeniden adlandırılırsa kopar. Kalıcı çözüm: `SavedPlaceSnapshot.placeId` (migration gerekir).
- Paywall placeholder + AdMob test ID'leri → **bu haliyle YAYINLANAMAZ** (ROADMAP §3).
- `PinlyTests/` altında testler + mock'lar yazıldı ama pbxproj'da test target'ı `MASTER_PLAN.md` Faz 3'te ekleniyor (bu adım tamamlanana kadar testler derlenmiyor).

---

## UI Yapısı
```
TabView (HomeView)
  ├── Ana (house)                    — MainTab: istatistik şeridi + hero CTA + hızlı aksiyonlar + son eklenenler
  ├── Keşfet (square.grid.2x2)       — DiscoverView: kategorilere göre mekanlar
  ├── Rotalar (map)                  — SavedRoutesView: önceden planlanmış rotalar
  └── Profil (person.crop.circle)    — ProfileTab: avatar, tema/görünüm, İstatistikler, Geçmiş, Haftalık Rapor, Rozetler, Dil
```

## Yapılanlar (özet — detay IMPROVEMENT_PLAN.md'de)
- Mekan CRUD (adres/mevcut konum/haritada pinle), arama+filtre+sıralama, kategori sistemi
- Rota oluşturma (2 akış), turn-by-turn navigasyon, sapma algılama, Live Activity + Dynamic Island
- Kayıtlı rotalar (kaydet/düzenle/başlat/uzaklık uyarısı), rota geçmişi, haftalık rapor, profil istatistikleri
- 21 rozet + banner sistemi, gün serisi
- Paylaşım: QR tek mekan, rota linki (base64), GPX/PDF export (Pro), Instagram paylaşım kartı, Swarm import
- Freemium altyapısı (20 mekan limiti, 7 gate noktası), AdMob interstitial kodu (test ID)
- 5 dil (tr/en/es/de/ru) uygulama içi değiştirilebilir, onboarding, doğal tema, app icon, Hızlı Ekle widget
- MVVM + protokol servis refactor'ü (FreemiumManager/BadgeManager silindi), B1-B15 bugları düzeltildi

## Yapılacaklar (öncelik sırasıyla)

### Apple Developer Hesabı Alınınca (EN ÖNCE)
- [ ] RevenueCat SPM + App Store Connect ürünleri (`pinly_pro_monthly` $4.99, `pinly_pro_yearly` $39.99)
- [ ] `LocalEntitlementService` → `RevenueCatEntitlementService` (protokol sayesinde tek dosya)
- [ ] PaywallView butonları → gerçek purchase/restore (TODO comment'leri var)
- [ ] AdMob gerçek ID'ler (Info.plist `GADApplicationIdentifier` + `AdManager.interstitialAdUnitID`) + ATT izni
- [ ] Crash reporting + analytics (Crashlytics/Sentry), TestFlight beta

### Apple Developer olmadan yapılabilecekler
- [ ] Unit test paketi (ROADMAP §2.3) + GitHub Actions CI — **yürütülüyor: `MASTER_PLAN.md` Faz 3/6**
- [ ] `SavedPlaceSnapshot.placeId` (isim eşleşmesi kırılganlığı)
- [ ] Toplu mekan silme (edit modu + multi-select)
- [ ] Haritada Keşfet modu + "gitmediklerim" filtresi
- [ ] Rota paylaşım önizlemesi (özet kart)
- [ ] Hazır İstanbul rota paketleri (JSON bundle — boş uygulama problemi)
- [ ] Bildirim iznini onboarding'den Haftalık Rapor ekranına taşımayı değerlendir

### Faz 3 (backend sonrası)
- [ ] Supabase (hesap, feed, takip), iCloud Sync, Push, AI rota asistanı (Claude API + Edge Function proxy), Offline harita (Mapbox, Pro), Apple Watch

## Kararlar & Notlar
- Arapça lokalizasyon istenmiyor; TR/EN/ES/DE/RU tamam
- Booking.com affiliate istenmiyor (şimdilik)
- Sosyal feed: önce anonim paylaşım (URL scheme), sonra hesap sistemi
- UI yönü: "slate" palet (2026-07) — koyu slate-navy zeminler + beyaz kartlar + slate-indigo aksan; meditasyon-app referansı. Önceki "doğal çam" (ve ondan önce coral) paleti reddedildi; YEŞİL KULLANILMAYACAK. Buz mavisi/beyaz aksan da denenebilir (kullanıcı ikisine de açık). Tab bar: custom "gooey" PinlyTabBar (view/home/PinlyTabBar.swift)
- Kullanıcı tercihi: büyük tasarım kararlarından ÖNCE sor (AskUserQuestion) — akışı birlikte yönetmek istiyor
- Hazır mahalle rotaları: influencer'lar Rota Paylaşımı özelliğiyle kendi rotalarını paylaşır
- AI Agent API key güvenliği: Supabase Edge Function proxy (client-side key kabul edilemez)
- `landing/index.html` web varlığı olarak repoda duruyor; uygulama içi tanıtım rolü OnboardingView'de
