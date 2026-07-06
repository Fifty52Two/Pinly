# Pinly — İyileştirme Planı (2026-07-05)

> Bu dosya, kod incelemesi sonucu bulunan sorunların ve iyileştirmelerin tam listesidir.
> Herhangi bir session/model buradan devam edebilir. Tamamlanan maddeler `[x]` işaretlenir.

## 1. Gelir Değerlendirmesi (özet)

**Mevcut haliyle pasif gelir ÜRETEMEZ**, çünkü:
- Apple Developer hesabı yok → App Store'da yayında değil → 0 kullanıcı, 0 gelir.
- `PaywallView` "Pro'ya Geç" butonu ödeme almadan `FreemiumManager.isPro = true` yapıyor (placeholder). Bu haliyle yayınlanırsa **herkes Pro'yu bedava alır** — yayın öncesi RevenueCat şart.
- AdMob test ID'leri kullanılıyor (`Info.plist` GADApplicationIdentifier + `AdManager.interstitialAdUnitID`) → test reklamları gelir getirmez.

**Potansiyel:** Konsept sağlam (Foursquare City Guide boşluğu + Swarm import ile kullanıcı çekme kancası gerçekten iyi bir fikir). Ama "pasif" gelir beklentisi gerçekçi değil: pazarlama/ASO olmadan bu tip utility uygulamalar ayda ~$0-50 bandında kalır. 100K kullanıcı hedefi aktif pazarlama ister. Gelir mimarisi (freemium 20 mekan limiti + interstitial + Pro export/offline) doğru kurgulanmış; eksik olan dağıtım.

**Yayın öncesi zorunlu:** RevenueCat entegrasyonu, gerçek AdMob ID'leri, App Privacy formu (konum + HealthKit + reklam takibi), ATT (AppTrackingTransparency) izni — AdMob kişiselleştirilmiş reklam için gerekli.

## 2. Bulunan Buglar (öncelik sırasıyla)

- [x] **B1 — Rota segmenti kayması:** `RouteManager.calculateRoutes` başarısız segmentleri `compactMap` ile düşürüyor → `stepsPerSegment`/`segmentDistances`/`routePolylines` ile `routePlaces` indeksleri kayıyor; navigasyon yanlış talimat gösterir. Fix: başarısız segment için boş placeholder tut, hizalamayı koru.
- [x] **B2 — Harita pan kilidi:** `NavigationMapView.updateUIView` her güncellemede `map.setRegion(region)` çağırıyor → kullanıcı haritayı kaydıramıyor (geri fırlıyor). Fix: sadece region *değeri değiştiğinde* setRegion (coordinator'da son set edilen region cache'lenir).
- [x] **B3 — Pulse annotation kayboluyor:** `NavigationMapView` her update'te `NextWaypointAnnotation`'ı siliyor ama koordinat değişmediyse geri eklemiyor → navigasyonda hedef pulse'ı ilk konum güncellemesinde yok oluyor. Fix: koordinat değişmediyse silme.
- [x] **B4 — Overlay flicker:** her `updateUIView`'de tüm overlay+annotation silinip ekleniyor (10 m'de bir) → titreme + CPU. Fix: sadece değişince yeniden kur.
- [x] **B5 — Tek mekan navigasyonu kilitleniyor:** `MapView` → "Navigate Here" akışında `dismissRouteFlow` environment'ı set edilmiyor → RouteSummaryView'deki X ve rota tamamlama overlay'i default no-op çağırıyor; kullanıcı `routeManager.reset()` sonrası boş ekranda kalıyor. Fix: MapView fullScreenCover'a `.environment(\.dismissRouteFlow, ...)` ver.
- [x] **B6 — Sabahçı kuş / gece kuşu rozetleri kazanılamıyor:** `BadgeManager.recordRouteStarted()` sadece SavedRoutesView'den çağrılıyor; normal "Navigasyonu Başlat" akışında yok. Fix: RouteSummaryView başlat butonuna ekle.
- [x] **B7 — Planlamacı rozeti tutarsız:** `RouteSummaryView` SaveRouteSheet ve `ContentView.saveRouteToSavedRoutes` `recordSavedRoute()` çağırmıyor (sadece PlanRouteView çağırıyor). Fix: her iki noktaya ekle + badge check.
- [x] **B8 — Live Activity güncellenmiyor:** durak varışında/`resumeNavigation`'da `updateLiveActivity()` çağrılmıyor; rota tamamlanınca `endLiveActivity()` overlay kapanana dek çağrılmıyor. Fix: bu üç noktaya ekle.
- [x] **B9 — Dosya adı sanitizasyonu:** PDF/GPX export'ta rota adı `/` içerirse (`"Kadıköy/Moda Turu"`) dosya yazımı sessizce başarısız. Fix: dosya adından geçersiz karakterleri temizle.
- [x] **B10 — SavedRouteManager.save koordinatsız mekanlar:** hiç koordinat yoksa merkez (0,0) (Atlantik) oluyor; snapshot lat/lon 0 yazılıyor. Fix: koordinatlı mekan yoksa İstanbul default; snapshot'a mevcut merkez yaz.
- [x] **B11 — CategoryPickerView sonsuz spinner:** kullanıcı hiç mekan eklememişse "Mekanlar yükleniyor..." sonsuza dek döner. Fix: gerçek boş durum göster.
- [x] **B12 — QR kamera preview frame:** rotation/layout değişiminde previewLayer boyutu güncellenmiyor. Fix: updateUIView'de frame güncelle.
- [x] **B13 — DiscoverView ölü X butonu:** Keşfet bir tab; `dismiss()` hiçbir şey yapmıyor. Fix: butonu kaldır.
- [x] **B14 — AdManager scene lookup:** `connectedScenes.first as? UIWindowScene` ilk scene window scene değilse reklam hiç gösterilmez. Fix: `compactMap.first`.
- [x] **B15 — RouteHistory adı hep "Rota":** kayıtlı rotadan başlatınca gerçek rota adı kaydedilmiyor. Fix: `RouteManager.routeName` alanı; SavedRoutesView set eder, history + Live Activity kullanır.

## 3. Mimari / SOLID İyileştirmeleri

- [x] **A1 — RouteManager rota kurulum API'si:** `selectedCategories`/`selectedPlaces` dictionary hack'i (MapView `uuid` key, SavedRoutesView `"i_uuid"` key) yerine `setRoute(places:name:)` metodu. Tek sorumluluk + çağıranlar sadeleşir.
- [x] **A2 — RouteManager @MainActor:** @Published mutasyonları main thread garanti altına alınır (şu an DispatchQueue.main elle serpiştirilmiş).
- [x] **A3 — Paylaşım sheet helper:** `UIApplication...rootViewController?.present` kopyası (PDF+GPX) tek helper'a indirildi.
- [x] **A4 — calculateRoutes async yapısı korundu** ama hizalama + hata dayanıklılığı eklendi (bkz B1).
- [ ] **A5 — (İsteğe bağlı, sonraya)** FreemiumManager/BadgeManager protokol arkasına alınıp test edilebilirlik — şu ölçekte över-engineering, bilinçli ertelendi.

## 4. UI / UX İyileştirmeleri

- [x] **U1 — Hardcoded string'ler lokalize edildi:** "Düzenle", "Sil", "Paylaş", "Rotayı Güncelle", "Gidilecek", "Ziyaret Edildi", Keşfet istatistik pill'leri, RouteOverviewPanel süre formatı ("dk"/"s"), SwarmImportView butonları, "İçe Aktarılan Rota". 5 dile eklendi (tr/en/de/es/ru).
- [x] **U2 — MapView annotation güncelliği:** kategori/renk düzenlemesi haritaya yansımıyordu (sadece ID seti karşılaştırılıyordu). Kategori de karşılaştırmaya eklendi.
- [x] **U3 — RouteOverviewPanel süre formatı lokalize.**

## 5. FAZ 2 — "Bir Üst Seviye" Planı (2026-07-05, ikinci tur)

### SOLID Denetimi (dürüst cevap)
| İlke | Durum | Not |
|---|---|---|
| **S**RP | ⚠️ Kısmen | `ContentView.swift` (1200+ satır, 8 view) ve `RouteSummaryView.swift` (1200+ satır: navigasyon + paylaşım + export + rating + kaydetme) tek dosyada çok iş yapıyor. View'lar mantık barındırıyor (import/freemium akışları). |
| **O**CP | ⚠️ Kısmen | `PlaceCategory`/`Badge` switch tabanlı — yeni kategori 4-5 switch'e dokunmayı gerektiriyor. Uygulama ölçeğinde kabul edilebilir; Badge data-driven yapıya geçirilebilir. |
| **L**SP | ✅ | Kalıtım neredeyse yok; sorun yok. |
| **I**SP | ⚠️ | View'lar dev manager'ların tamamını `@EnvironmentObject` alıyor, ihtiyaç duydukları dilimi değil. |
| **D**IP | ❌ En zayıf | `FreemiumManager`/`BadgeManager` static enum, `AdManager.shared` singleton — protokol yok, test edilemez, mock'lanamaz. RevenueCat geçişinde `FreemiumManager` protokol arkasına alınmalı (`EntitlementProviding`). |

Karar: DIP refactor'ü RevenueCat entegrasyonuyla birlikte yapılacak (iki kez ellenmesin). SRP için dosya bölme bu fazda değil (churn/yarar oranı düşük) — bir sonraki fazda `view/home/`, `view/route/` klasörlerine bölünecek.

### Marka Kimliği (yeni)
- Ana renk: **Pinly Coral** `#FF6B57` → gradient `#FF8E53`; koyu zemin: Navy `#101A33`; ikincil: Indigo `#5B5FEF`
- `Pinly/design/Theme.swift` — renkler + kart stili + buton stilleri tek yerde (yeni bileşenler bunu kullanır)

### Yapılacaklar
- [x] **P1 — App Icon:** AppIcon.appiconset BOŞTU (uygulamanın ikonu yok!). CoreGraphics script ile 1024×1024 light/dark/tinted üretildi (`scripts/generate_icon.swift`)
- [x] **P2 — Onboarding (3 sayfa):** ilk açılışta marka gradient'li tanıtım akışı; `pinly.hasSeenOnboarding` @AppStorage
- [x] **P3 — Ana ekran redesign:** saate göre selamlama, istatistik şeridi (mekan/ziyaret/seri/rozet), gradient hero CTA, hızlı aksiyonlar, "Son Eklenenler" yatay listesi
- [x] **P4 — Profil İstatistikleri ekranı:** toplam km/adım/rota, en çok gidilen kategori, seri — MoreTab'a eklendi
- [x] **P5 — Viral paylaşım kartı:** rota tamamlanınca Instagram-story formatında görsel kart (ImageRenderer) + paylaş butonu — büyüme kancası
- [x] **P6 — Landing page:** `landing/index.html` — self-contained, TR, hero + özellikler + SSS (agent üretti)
- [x] **P7 — Tab bar + Paywall theme uyumu:** coral tint
- [ ] **P8 — (sonraki faz)** Dosya bölme (SRP), Badge data-driven, Haritada Keşfet modu, toplu silme

## 6. FAZ 3 — Doğal UI + Tam SOLID + Pinleme (2026-07-06)

### Kullanıcı geri bildirimi
- Önceki UI "AI kokuyor / sentetik" (coral gradientler, navy neon) → **doğal palet** istendi; referans: Airbnb/AllTrails (muted tonlar, flat, beyaz/ılık yüzeyler, tek kısık aksan)
- "Landing page" aslında **uygulama içi tanıtım** olarak düşünülmüştü → OnboardingView o rol; HTML sayfa repo'da kalıyor (web varlığı olarak zararsız)
- Tam SOLID istendi; mimari seçimi bana bırakıldı → **MVVM + protokol tabanlı servis katmanı** seçildi
- Yeni özellik: **Haritada Pinle** — mekan eklerken haritayı gezip pin bırakarak konum seçme

### Yapılanlar
- [x] **N1 — "Doğal" palet:** Theme.swift yeniden yazıldı. Çam yeşili aksan (#33684E light / #6BA885 dark), kil (#B56A47), altın, arduvaz destek tonları; ılık kâğıt zemin (#F6F4EF / #171614); gradient kaldırıldı (hero "gradyanı" aynı ailede iki komşu ton = flat okunur); kartlarda gölge yerine ince kontur. Tüm renkler dynamic (dark mode otomatik).
- [x] **N2 — Onboarding restyle:** koyu navy → ılık kâğıt zemin, sistem metin renkleri, kısık aksan halkaları
- [x] **N3 — Ana ekran/Paywall/ProfileStats** doğal palete geçirildi (token'lar üzerinden)
- [x] **N4 — App icon** doğal palete yeniden üretildi (çam zemin + ılık beyaz pin + kum rota)
- [x] **N5 — Haritada Pinle (Agent A):** MapPinPickerView (sabit merkez pin, haritayı altında kaydır, debounce'lu reverse geocode) + AddPlaceView/EditPlaceView entegrasyonu + 5 dil
- [x] **N6 — SOLID/MVVM refactor:** TAMAMLANDI (agent + ana session). Sonuç:
  - `Pinly/services/`: EntitlementService.swift (`EntitlementProviding` + `LocalEntitlementService`, RevenueCat'e hazır), BadgeService.swift (`BadgeServicing` + `DefaultBadgeService`), AdService.swift (`AdPresenting`; AdManager conform, entitlements constructor-injected), ServiceEnvironment.swift (`\.entitlements`, `\.badges`, `\.ads` environment key'leri; PinlyApp composition root)
  - `FreemiumManager` ve `BadgeManager` SİLİNDİ — static çağrı kalmadı (grep temiz); Badge enum `model/Badge.swift`'e taşındı, `progressText(placeStore:badges:)` imzası değişti
  - Dosya bölme: ContentView.swift 1300→240 satır (`view/home/`: MainTab, PlacesListView, MoreTab, ImportViews, StatusViews + PlacesListViewModel); RouteSummaryView.swift 1300→666 satır (`view/route/`: NavigationMapView, NavigationBanner, RouteCompletionOverlay, RatingSheetView, RouteSharePickerView, SaveRouteSheet)
  - PlacesListViewModel: arama/filtre/sıralama mantığı view'dan çıkarıldı
- [x] **N7 — Build + simülatör smoke test:** BUILD SUCCEEDED; light/dark ana ekran + RU lokalizasyon simülatörde doğrulandı

### N6 detayı (Agent B brief'i / sonraki session için)
1. `Pinly/services/` klasörü: `EntitlementProviding` (isPro, canAddPlace) → `LocalEntitlementService` (UserDefaults; RevenueCat'e hazır); `BadgeServicing` → BadgeManager sarmalayıcı; `AdPresenting` → AdManager sarmalayıcı
2. SwiftUI Environment üzerinden enjeksiyon (`@Environment(\.entitlements)` custom key'ler); static çağrılar (FreemiumManager.canAddPlace, BadgeManager.check, AdManager.shared) bu protokollere yönlendirilir
3. Dosya bölme (SRP): ContentView.swift → view/home/{HomeView,MainTab,PlacesListView,MoreTab,RouteImportView,SwarmImportView}.swift; RouteSummaryView.swift → view/route/{RouteSummaryView,NavigationMapView,RouteCompletionOverlay,RatingSheet,SharePicker}.swift
4. ViewModel'ler: PlacesListViewModel (filtre/sıralama mantığı view'dan çıkar), RouteSummaryViewModel (tamamlama/paylaşım orkestrasyonu)
5. Her adımda `xcodebuild ... build` yeşil kalmalı

## 7. Sonraki Session İçin Yapılacaklar (kod dışı / büyük işler)

1. **Xcode'da derleyip smoke test** (bu ortamda xcodebuild denendi; simülatör/DerivedData durumuna göre `xcodebuild -project Pinly.xcodeproj -scheme Pinly -destination 'platform=iOS Simulator,name=iPhone 16' build`).
2. Apple Developer hesabı → CLAUDE.md'deki RevenueCat adımları (paywall şu an bilerek placeholder).
3. AdMob gerçek ID'leri + ATT izni (`NSUserTrackingUsageDescription` + `ATTrackingManager.requestTrackingAuthorization`).
4. Bildirim izni istemini ilk açılıştan çıkarıp Haftalık Rapor ekranına taşımayı düşün (onboarding UX).
5. PlanRouteView edit modunda snapshot eşleşmesi isimle yapılıyor — mekan yeniden adlandırılırsa seçim kaybolur; snapshot'a `placeId` eklemek kalıcı çözüm (migration gerekir).
6. Profil istatistikleri ekranı, Haritada Keşfet, toplu silme (CLAUDE.md backlog'unda).
