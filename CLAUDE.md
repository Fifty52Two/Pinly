# Pinly — Proje Bağlamı

## Proje Nedir
iOS SwiftUI uygulaması. Mekan kaydetme + yürüyüş rotası planlama + navigasyon.
Foursquare City Guide Aralık 2024'te kapandı — Türkiye global trafiğin %9'unu oluşturuyordu.
Bu boşluğu doldurmak için konumlanmış. Türkiye + turist odaklı, ilerleyen süreçte MENA/Balkanlar.

## Hedef
Freemium model, $4.99/ay Pro. 18 ayda 100K kullanıcı → $8-15K/ay gelir.

## Teknik Stack
- SwiftUI + SwiftData (iOS 17+)
- MapKit (MKDirections, turn-by-turn navigasyon)
- ActivityKit (Live Activities kilit ekranında)
- Deep link: `pinly://` scheme (eski `notiongo://` backwards compat)
- Xcode projesi: `Pinly.xcodeproj` — klasörler: `Pinly/`, `PinlyLiveActivity/`

## SourceKit Uyarıları Hakkında
SourceKit "Cannot find X in scope" hataları FALSE POSITIVE'dir.
SourceKit'in Xcode build context'i yoktur. Xcode'da compile edilir, sorun yoktur.
Bu hatalar için kod değiştirme.

## Dosya Yapısı (önemli dosyalar)
```
Pinly/
  PinlyApp.swift              — @main entry, modelContainer: Place + RouteHistory + SavedRoute
  ContentView.swift           — TabView (Ana/Keşfet/Rotalar/Daha Fazla), HomeView→MainTab
  model/
    Place.swift               — Place model + PlaceCategory enum
    PlaceImporter.swift       — URL build/parse, Swarm import, RouteCategory enum
    RouteHistory.swift        — Tamamlanan rota geçmişi @Model
    SavedRoute.swift          — Önceden planlanmış rotalar @Model + SavedPlaceSnapshot
    PinlyActivityAttributes.swift
  manager/
    FreemiumManager.swift     — 20 mekan limiti, isPro flag (UserDefaults)
    RouteManager.swift        — Navigasyon state + Live Activity
    LocationManager.swift
    PlaceStore.swift
    SavedRouteManager.swift   — SavedRoute CRUD + uzaklık hesabı
    BadgeManager.swift        — 10 rozet, UserDefaults
    WeeklyReportManager.swift — İstatistik + Pazar bildirimi
    HealthKitManager.swift    — Adım + mesafe sorgusu
    AdManager.swift           — AdMob interstitial
  view/
    RouteSummaryView.swift    — Navigasyon + RouteSharePickerView + SaveRouteSheet
    MapView.swift
    PlanRouteView.swift       — Pin bırak → kendi mekanları seç → kaydet (MapReader)
    SavedRoutesView.swift     — Kayıtlı rotalar listesi, uzaklık uyarısı, başlatma
    AddPlaceView.swift
    EditPlaceView.swift
    PlaceDetailView.swift
    SharePlaceView.swift
    QRScannerView.swift
    PaywallView.swift
    DiscoverView.swift
    BadgesView.swift
    RouteHistoryView.swift
    WeeklyReportView.swift
  Info.plist                  — URL scheme: pinly (+ notiongo backwards compat)
  tr.lproj/Localizable.strings
  en.lproj/Localizable.strings
PinlyLiveActivity/            — Widget extension
```

## UI Yapısı
```
TabView (HomeView)
  ├── Ana (house.fill)         — MainTab: Mekanlarım + Rota Planla kartları
  ├── Keşfet (grid)            — DiscoverView: kategorilere göre mekanlar
  ├── Rotalar (bookmark.map)   — SavedRoutesView: önceden planlanmış rotalar
  └── Daha Fazla (ellipsis)    — MoreTab: Geçmiş, Haftalık Rapor, Rozetler
```

## Yapılanlar (tamamlanan özellikler)

### Temel Altyapı
- [x] Mekan kaydetme (SwiftData), kategori, adres, koordinat, not
- [x] Yürüyüş rotası + turn-by-turn navigasyon
- [x] Live Activities (kilit ekranı navigasyon banner)
- [x] Ziyaret takibi + kullanıcı puanlama (1-5 yıldız)
- [x] TR/EN/DE/ES/RU lokalizasyon — tüm view'lar String(localized:) ile tam lokalize edildi
- [x] QR kod ile tek mekan paylaşımı + derin link import

### Freemium Gate
- [x] `FreemiumManager` — 20 mekan ücretsiz limiti
- [x] `PaywallView` — Pro faydaları + "Yakında" badge (offline harita, grup rotaları)
- [x] 4 gate noktası: PlacesListView +, MapView +, QRScannerView import, deep link import

### Arama & Filtre
- [x] `.searchable` — isim + adres üzerinden
- [x] Kategori chip filtreleri (yatay scroll)

### Rota Link Paylaşımı
- [x] `PlaceImporter.buildRouteURL(for:name:category:)` — base64 JSON URL
- [x] `PlaceImporter.parseRouteFull(url:)` → `RouteImport` struct (isim + kategori + mekanlar)
- [x] `RouteSharePickerView` — paylaşmadan önce isim + kategori seçimi
- [x] `RouteImportView` — alıcı tarafta import confirmation sheet
- [x] Backwards compat: eski plain-array format da kabul edilir

### Rota Kategorileri
- [x] `RouteCategory` enum: Şehir İçi / Şehir Dışı / Yurt Dışı
- [x] Paylaşım URL'sine embed edilir, import ekranında gösterilir

### Swarm Import
- [x] `PlaceImporter.parseSwarm(data:)` — Foursquare checkins.json parse
- [x] Venue ID bazlı tekilleştirme
- [x] Foursquare kategori → PlaceCategory eşlemesi (8 kategori)
- [x] `SwarmImportView` — preview + freemium gate
- [x] PlacesListView toolbar'da `↓` butonu → file picker

### App Rename
- [x] NotionGO → Pinly (tüm string referanslar)
- [x] URL scheme: `pinly://` (+ `notiongo://` backwards compat)
- [x] UserDefaults key: `pinly.isPro` (+ `notiongo.isPro` migration)

## Yapılacaklar (öncelik sırasıyla)

### Apple Developer Hesabı Alınınca (EN ÖNCE BUNLAR)
- [ ] Xcode → SPM → `https://github.com/RevenueCat/purchases-ios-spm` ekle
- [ ] App Store Connect → `pinly_pro_monthly` ($4.99/ay) + `pinly_pro_yearly` ($39.99/yıl) oluştur
- [ ] RevenueCat Dashboard → Entitlement `"pro"` + Offering `"default"` → API key al
- [ ] `PinlyApp.swift` → `Purchases.configure(withAPIKey: "...")` ekle
- [ ] `FreemiumManager.isPro` getter → `cachedCustomerInfo` ile değiştir (TODO comment'i var)
- [ ] `PaywallView` butonları → gerçek `Purchases.shared.purchase/restore` (TODO comment'leri var)

### Faz 1 — Kalan
- [ ] AdMob SPM paketi Xcode'dan eklenmeli → `https://github.com/googleads/swift-package-manager-google-mobile-ads`
- [x] AdMob interstitial kodu yazıldı (rota tamamlama + rota paylaşımı)
- [ ] Yayına geçerken: Info.plist `GADApplicationIdentifier` + `AdManager.interstitialAdUnitID` → gerçek ID'ler

### Faz 2 — Büyüme (Apple Developer öncesi yapılabilecekler)
- [x] Rota Export GPX — Pro gate, `PlaceImporter.buildGPXFile`
- [x] Rota Export PDF — `PlaceImporter.buildPDFFile` (PDFKit+UIKit), Pro gate
- [x] Mekan Detay View — `PlaceDetailView.swift`
- [x] Rozet/Ödül Sistemi — `BadgeManager.swift` (10 rozet)
- [x] Lokalizasyon tamamlama — TR + EN + DE + ES + RU; tüm view'lar tam lokalize
- [x] HealthKit Entegrasyonu — `HealthKitManager.swift`
- [x] Rota Geçmişi — `RouteHistory.swift` @Model, `RouteHistoryView.swift`
- [x] Haftalık Rapor — `WeeklyReportManager.swift`, `WeeklyReportView.swift`
- [x] **Kayıtlı Rotalar** — `SavedRoute.swift` @Model, `SavedRouteManager.swift`, `PlanRouteView.swift` (MapReader pin + kendi mekanları), `SavedRoutesView.swift`; RouteSummaryView'e "Rotayı Kaydet" butonu eklendi
- [x] **Tab Bar UI** — 4 sekme: Ana / Keşfet / Rotalar / Daha Fazla; ana ekran sadeleşti (2 kart)
- [ ] **Offline Harita (Pro)** — Mapbox SDK gerekiyor, hesap açılınca yapılacak

### Apple Developer olmadan yapılabilecek sıradaki özellikler

#### Kullanıcı Deneyimi İyileştirmeleri
- [ ] **Mekan sıralama seçeneği** — PlacesListView'de: eklenme tarihi / alfabetik / mesafe / ziyaret sayısı
- [ ] **Rota paylaşım önizlemesi** — paylaşmadan önce rota özet kartı (mekan isimleri + tahmini süre)
- [ ] **Toplu mekan silme** — PlacesListView'de edit modu + multi-select delete
- [x] **PlaceDetailView harita önizlemesi** — gerçek Map + paylaş butonu eklendi
- [x] **Widget (iOS Home Screen)** — "Hızlı Ekle" small/medium widget; `pinly://quickadd` deep link → `QuickAddSheet`

#### Rota Geliştirmeleri
- [x] **Rota önizleme haritası** — SavedRoutesView kart thumbnail harita eklendi
- [x] **Rota kopyalama / düzenleme** — SavedRoutesView swipe "Düzenle" → PlanRouteView edit modu
- [x] **Rota paylaşımından direkt kaydet** — RouteImportView'e "Kayıtlı Rotalarıma Ekle" butonu eklendi

#### Keşfet Geliştirmeleri
- [ ] **Haritada Keşfet** — DiscoverView'e harita modu, mekanlar haritada görünsün
- [ ] **Ziyaret edilmemişleri filtrele** — Keşfet'te "Henüz gitmediklerim" filtresi

#### Analitik / Gamification
- [x] **Rozet artırma** — 10 → 22 rozet; sabahçı kuş, gece kuşu, müze kurdu, park sever, sosyal kelebek, hafızalık vb.
- [ ] **Profil istatistikleri ekranı** — toplam km, ziyaret, en çok gidilen kategori, en aktif gün

#### Live Activity & Widget
- [x] **Live Activity fix** — PinlyLiveActivityBundle doğru widget'a bağlandı; lock screen'e "Navigasyona Dön" butonu eklendi
- [x] **Home Screen "Hızlı Ekle" widget** — `QuickAddWidget.swift` (PinlyLiveActivity target), `QuickAddSheet.swift`; deep link yaklaşımı (App Groups gerekmez)

#### Auth UI (diğer developer)
- [ ] **Sign In / Sign Up ekranları** — AuthView, SignInView, SignUpView, ForgotPasswordView + AuthManager

#### Mekan Paylaşımı
- [x] **PlaceDetailView'de Paylaş butonu** — toolbar + kart altında; SharePlaceView açılıyor

### Apple Developer + Backend sonrası (Faz 3)
- [ ] **RevenueCat** — gerçek in-app purchase (pinly_pro_monthly $4.99, pinly_pro_yearly $39.99)
- [ ] **Supabase backend** — kullanıcı hesabı, rota paylaşım feed, takipçi sistemi
- [ ] **iCloud Sync** — SwiftData + CloudKit
- [ ] **Push Notifications** — sosyal feed bildirimleri
- [ ] **AI Agent** — Claude API + Supabase Edge Function proxy; kullanıcı doğal dilde rota ister, agent kendi mekanlarından öneri üretir
- [ ] **Offline Harita (Pro)** — Mapbox SDK
- [x] **Lokalizasyon genişletme** — ES / DE / RU tamamlandı (`es.lproj`, `de.lproj`, `ru.lproj`)

## Kararlar & Notlar
- Arapça lokalizasyon istenmiyor, sadece TR + EN (belki ES, DE, RU daha sonra)
- Booking.com affiliate istenmiyor (şimdilik)
- Sosyal feed: önce anonim paylaşım (URL scheme), sonra hesap sistemi
- B2B detayı sonra konuşulacak
- Hazır mahalle rotaları: influencer'lar Rota Paylaşımı özelliğiyle kendi rotalarını paylaşır
- Swarm export'ta tam adres var: address + city + lat/lng + Foursquare categories
- AI Agent için API key güvenliği: Supabase Edge Function proxy (client-side key kabul edilemez)
