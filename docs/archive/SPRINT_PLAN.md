# SPRINT_PLAN.md — Büyüme Sprinti (2026-07-14)

> Fable 5'in denetim bulgularını (7 eksik) kapatan uçtan uca uygulama planı.
> Bu belge **uygulayıcı model için yazılmıştır**: her fazda ne yapılacağı, hangi dosyada,
> hangi satır çapasında (anchor) ve hangi kodla yapılacağı verilmiştir.
> **Tasarım kararı verme, alternatif üretme, plandan sapma.** Plan gerçekle çelişirse
> (dosya taşınmış, API değişmiş) DUR ve kullanıcıya raporla.

---

## Kurallar (her fazda geçerli)

1. **Önce `CLAUDE.md`'yi oku.** SourceKit "Cannot find X in scope" hataları false positive'dir — kod değiştirme.
2. **Doğrulama komutu** (her fazın sonunda, geçmeden commit yok):
   ```bash
   xcodebuild -scheme Pinly -destination 'platform=iOS Simulator,name=iPhone 16' test
   ```
   Çıktıda `** TEST SUCCEEDED **` VE `Executed N tests` (N > 0) görülmeli.
3. **Faz başına tek commit.** Mesajlar her fazın sonunda verilmiştir — aynen kullan
   (`tip: açıklama`, tek satır, Türkçe). Push yapma.
4. **Çalışma dalı:** işe başlamadan önce bir kez:
   ```bash
   git checkout -b feat/buyume-sprinti
   ```
5. **Lokalizasyon:** her yeni kullanıcı metni `NSLocalizedString` ile yazılır; anahtar
   Türkçe metnin kendisidir. Her fazın sonundaki `.strings` blokları **5 dosyaya da**
   (`Pinly/tr.lproj`, `en.lproj`, `es.lproj`, `de.lproj`, `ru.lproj` altındaki
   `Localizable.strings`) dosya sonuna aynen eklenir. `tr.lproj` için değer = anahtar.
6. **Renkler yalnızca `PinlyTheme`'den** (`Pinly/Design/Theme.swift`). Yeşil YASAK.
7. Fazlar sıralı ve bağımsızdır: 1 → 7. Bir faz bitip commit'lenmeden diğerine geçme.

---

## FAZ 1 — 🔴 Arka Plan Navigasyonu (çekirdek vaadi onar)

**Sorun:** `UIBackgroundModes` yok, `allowsBackgroundLocationUpdates` hiç çağrılmıyor.
Telefon cebe girince konum güncellemeleri duruyor; Live Activity donuyor, varış tespiti ölüyor.

**Sıra önemli: önce 1.1 (pbxproj), sonra 1.2 (kod).** Background mode olmadan
`allowsBackgroundLocationUpdates = true` çalışma anında exception fırlatır.

- [ ] **1.1 `Pinly.xcodeproj/project.pbxproj`** — `Pinly` app target'ının Debug ve Release
  build config bloklarına (yalnızca `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`
  satırını İÇEREN iki blok — widget/test bloklarına DOKUNMA) şu satırı ekle.
  Konum: `INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;` satırının
  hemen ALTINA (alfabetik sıra):
  ```
  				INFOPLIST_KEY_UIBackgroundModes = location;
  ```
  (Bugünkü konumları: ~satır 587 (Debug) ve ~satır 622 (Release). Satır kaymış olabilir —
  çapa satırı ara, satır numarasına güvenme.)

- [ ] **1.2 `Pinly/Managers/LocationManager.swift`** — iki metodu güncelle:

  `startNavigationTracking()` içinde, `manager.distanceFilter = 10` satırından SONRA,
  `manager.startUpdatingLocation()` satırından ÖNCE ekle:
  ```swift
        // Telefon cebe girince de takip sürsün — UIBackgroundModes/location gerektirir.
        // "While Using" izniyle çalışır; sistem mavi göstergeyi gösterir.
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
  ```

  `stopNavigationTracking()` içinde, `manager.desiredAccuracy = kCLLocationAccuracyHundredMeters`
  satırından ÖNCE ekle (pil disiplini — navigasyon bitince arka plan takibi kapanır):
  ```swift
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
  ```

- [ ] **1.3 Doğrula** — build sonrası üretilen Info.plist'te anahtar var mı:
  ```bash
  xcodebuild -scheme Pinly -destination 'platform=iOS Simulator,name=iPhone 16' build
  /usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" \
    ~/Library/Developer/Xcode/DerivedData/Pinly-*/Build/Products/Debug-iphonesimulator/Pinly.app/Info.plist
  ```
  Beklenen çıktı: `Array { location }`. **Çıkmazsa:** 1.2'yi geri alma; kullanıcıya
  "Xcode → Pinly target → Signing & Capabilities → + Capability → Background Modes →
  Location updates işaretle" adımını yaptır, sonra PlistBuddy'yi tekrar koş.

- [ ] **1.4 Tam test koşusu** (Kural 2) → yeşil.

**Lokalizasyon:** bu fazda yeni kullanıcı metni yok.

**Commit:** `feat: navigasyon arka planda çalışıyor (UIBackgroundModes location + arka plan konum güncellemeleri)`

---

## FAZ 2 — 🔴 Hazır İstanbul Rotaları (boş uygulama problemi)

**Sorun:** Yeni kullanıcı onboarding sonrası bomboş ekranlarla karşılaşıyor.
**Çözüm:** Bundle'a gömülü 3 küratörlü rota → `SavedRoute` olarak tek dokunuşla eklenir.
SavedRoute snapshot'la çalıştığı için mekanlar Place tablosuna yazılmaz — **freemium
limitine dokunmaz**; `loadAndStart` koordinatlı geçici Place fallback'iyle zaten çalışıyor.

- [ ] **2.1 YENİ dosya `Pinly/Resources/StarterRoutes.json`** (klasörü oluştur; proje
  klasör-senkron olduğu için otomatik bundle resource olur). İçerik aynen:
  ```json
  [
    {
      "name": "Tarihî Yarımada Klasikleri",
      "routeCategory": "Şehir İçi",
      "places": [
        {"name": "Ayasofya", "category": "Historical Site", "address": "Sultan Ahmet, Ayasofya Meydanı No:1, Fatih/İstanbul", "latitude": 41.008583, "longitude": 28.980175},
        {"name": "Yerebatan Sarnıcı", "category": "Historical Site", "address": "Alemdar, Yerebatan Cd. 1/3, Fatih/İstanbul", "latitude": 41.008418, "longitude": 28.977908},
        {"name": "Sultanahmet Camii", "category": "Historical Site", "address": "Sultan Ahmet, Atmeydanı Cd. No:7, Fatih/İstanbul", "latitude": 41.005270, "longitude": 28.976960},
        {"name": "Gülhane Parkı", "category": "Park", "address": "Cankurtaran, Kennedy Cd., Fatih/İstanbul", "latitude": 41.013262, "longitude": 28.981478},
        {"name": "Mısır Çarşısı", "category": "General", "address": "Rüstem Paşa, Erzak Ambarı Sok. No:92, Fatih/İstanbul", "latitude": 41.016568, "longitude": 28.970483}
      ]
    },
    {
      "name": "Karaköy–Galata Keyfi",
      "routeCategory": "Şehir İçi",
      "places": [
        {"name": "Karaköy Güllüoğlu", "category": "Dessert", "address": "Kemankeş Karamustafa Paşa, Rıhtım Cd. No:3, Beyoğlu/İstanbul", "latitude": 41.022970, "longitude": 28.977860},
        {"name": "Salt Galata", "category": "Library", "address": "Azapkapı, Bankalar Cd. No:11, Beyoğlu/İstanbul", "latitude": 41.021111, "longitude": 28.973889},
        {"name": "Kamondo Merdivenleri", "category": "Historical Site", "address": "Bereketzade, Bankalar Cd., Beyoğlu/İstanbul", "latitude": 41.023889, "longitude": 28.973056},
        {"name": "Galata Kulesi", "category": "Historical Site", "address": "Bereketzade, Galata Kulesi Sok., Beyoğlu/İstanbul", "latitude": 41.025658, "longitude": 28.974183}
      ]
    },
    {
      "name": "Kadıköy–Moda Turu",
      "routeCategory": "Şehir İçi",
      "places": [
        {"name": "Kadıköy Tarihî Çarşı", "category": "General", "address": "Caferağa, Güneşli Bahçe Sok., Kadıköy/İstanbul", "latitude": 40.990278, "longitude": 29.023889},
        {"name": "Süreyya Operası", "category": "Historical Site", "address": "Caferağa, Gen. Asım Gündüz Cd. No:29, Kadıköy/İstanbul", "latitude": 40.987500, "longitude": 29.030400},
        {"name": "Moda Sahili", "category": "Park", "address": "Caferağa, Moda Cd., Kadıköy/İstanbul", "latitude": 40.980700, "longitude": 29.024900}
      ]
    }
  ]
  ```
  (`category` değerleri `PlaceCategory` kanonik rawValue'ları; `routeCategory` =
  `RouteCategory.city.rawValue`. Değiştirme.)

- [ ] **2.2 YENİ dosya `Pinly/Services/StarterRouteService.swift`** — aynen:
  ```swift
  import Foundation

  // MARK: - StarterRoute Modelleri

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

  // MARK: - StarterRoutesProviding

  /// Bundle'a gömülü hazır rotaların tek kaynağı — boş uygulama problemi için.
  protocol StarterRoutesProviding {
      func loadAll() -> [StarterRouteDefinition]
      func makeSavedRoute(from definition: StarterRouteDefinition) -> SavedRoute
  }

  struct DefaultStarterRoutesProvider: StarterRoutesProviding {
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
  }
  ```

- [ ] **2.3 `Pinly/Services/ServiceEnvironment.swift`** — mevcut desenle key ekle
  (diğer key struct'larının yanına + `EnvironmentValues` extension'ına):
  ```swift
  private struct StarterRoutesKey: EnvironmentKey {
      static let defaultValue: StarterRoutesProviding = DefaultStarterRoutesProvider()
  }
  ```
  ve extension içine:
  ```swift
      var starterRoutes: StarterRoutesProviding {
          get { self[StarterRoutesKey.self] }
          set { self[StarterRoutesKey.self] = newValue }
      }
  ```

- [ ] **2.4 `Pinly/PinlyApp.swift`** — diğer servislerin yanına
  `private let starterRoutesProvider = DefaultStarterRoutesProvider()` ekle ve
  `WindowGroup` zincirine `.environment(\.starterRoutes, starterRoutesProvider)` ekle.

- [ ] **2.5 `Pinly/Views/SavedRoutesView.swift`** — hazır rota bölümü:

  (a) Property'lere ekle (`@Query` satırının yanına):
  ```swift
      @Environment(\.starterRoutes) private var starterRoutes

      private var availableStarters: [StarterRouteDefinition] {
          let existing = Set(savedRoutes.map(\.name))
          return starterRoutes.loadAll().filter { !existing.contains($0.name) }
      }
  ```

  (b) `emptyState`'i ScrollView'a sar — mevcut `VStack(spacing: 20) { ... }` içeriğine
  DOKUNMADAN dışını değiştir:
  ```swift
      private var emptyState: some View {
          ScrollView {
              VStack(spacing: 20) {
                  // ... mevcut içerik AYNEN kalır ...
              }
              .padding(.top, 60)

              starterSection
                  .padding(.top, 28)
          }
      }
  ```
  (`.frame(maxWidth: .infinity, maxHeight: .infinity)` mevcut VStack'te varsa kaldır —
  ScrollView içinde gereksiz.)

  (c) `routeList` içindeki `List { ... }` bloğunda `ForEach(savedRoutes)`
  bloğunun KAPANIŞINDAN sonra ekle (hepsi eklendiyse `availableStarters` boş olur,
  `starterSection` kendini gizler):
  ```swift
              starterSection
                  .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                  .listRowSeparator(.hidden)
                  .listRowBackground(Color.clear)
  ```

  (d) Dosyanın sonuna (SavedRouteCard'ın yanına) yeni view'lar; `starterSection`'ı
  SavedRoutesView struct'ının İÇİNE, `StarterRouteCard`'ı dosya seviyesine koy:
  ```swift
      // MARK: - Hazır rotalar

      @ViewBuilder
      private var starterSection: some View {
          if !availableStarters.isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                  Text(NSLocalizedString("Hazır Rotalar", comment: ""))
                      .font(.headline)
                      .padding(.horizontal, 20)
                  ForEach(availableStarters) { definition in
                      StarterRouteCard(definition: definition) {
                          modelContext.insert(starterRoutes.makeSavedRoute(from: definition))
                      }
                      .padding(.horizontal, 20)
                  }
              }
          }
      }
  ```
  ```swift
  // MARK: - StarterRouteCard

  private struct StarterRouteCard: View {
      let definition: StarterRouteDefinition
      let onAdd: () -> Void

      var body: some View {
          VStack(alignment: .leading, spacing: 8) {
              HStack {
                  Text(definition.name)
                      .font(.headline)
                      .fontWeight(.semibold)
                  Spacer()
                  Label(
                      String(format: NSLocalizedString("%lld mekan", comment: ""), definition.places.count),
                      systemImage: "mappin.circle.fill"
                  )
                  .font(.caption)
                  .foregroundColor(PinlyTheme.primary)
              }

              Text(definition.places.prefix(3).map(\.name).joined(separator: " → ")
                   + (definition.places.count > 3 ? " +\(definition.places.count - 3)" : ""))
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .lineLimit(1)

              Button(action: onAdd) {
                  HStack {
                      Image(systemName: "plus.circle.fill")
                      Text(NSLocalizedString("Rotalarıma Ekle", comment: ""))
                          .fontWeight(.semibold)
                  }
                  .foregroundColor(PinlyTheme.slate)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 10)
                  .background(PinlyTheme.slate.opacity(0.10))
                  .cornerRadius(10)
              }
          }
          .padding(14)
          .background(PinlyTheme.surface)
          .cornerRadius(16)
      }
  }
  ```

- [ ] **2.6 `Pinly/Views/home/MainTab.swift`** — boş kullanıcıya sekme yönlendirme kartı:

  (a) Property ekle: `@Binding var selectedTab: Int`
  (b) `grep -rn "MainTab(" Pinly` ile TÜM çağrı yerlerini bul.
  `Pinly/Views/home/HomeView.swift` içindeki `MainTab()` → `MainTab(selectedTab: $selectedTab)`.
  Preview'larda → `MainTab(selectedTab: .constant(0))`.
  (c) Body'de `if !recentPlaces.isEmpty {` satırının (bugün ~satır 138) hemen ÖNCESİNE ekle:
  ```swift
                  if placeStore.places.isEmpty {
                      starterRoutesTeaser
                  }
  ```
  (d) MainTab struct'ının içine (diğer private view'ların yanına) ekle:
  ```swift
      // MARK: - Hazır rota yönlendirme kartı (boş uygulama problemi)

      private var starterRoutesTeaser: some View {
          VStack(alignment: .leading, spacing: 10) {
              HStack(spacing: 10) {
                  Image(systemName: "map.fill")
                      .font(.title3)
                      .foregroundColor(PinlyTheme.primary)
                  Text(NSLocalizedString("Hazır İstanbul rotalarını dene", comment: ""))
                      .font(.headline)
              }
              Text(NSLocalizedString("Küratörlü yürüyüş rotaları — tek dokunuşla rotalarına ekle.", comment: ""))
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              Button {
                  selectedTab = 2   // Rotalar sekmesi (HomeView tag'leri: 0 Ana, 1 Keşfet, 2 Rotalar, 3 Profil)
              } label: {
                  Text(NSLocalizedString("Keşfetmeye Başla", comment: ""))
                      .fontWeight(.semibold)
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 12)
                      .background(PinlyTheme.primary)
                      .foregroundColor(.white)
                      .cornerRadius(12)
              }
          }
          .padding(16)
          .pinlyCard()
          .padding(.horizontal, 20)
      }
  ```

- [ ] **2.7 YENİ test `PinlyTests/StarterRoutesProviderTests.swift`** — aynen:
  ```swift
  import XCTest
  @testable import Pinly

  final class StarterRoutesProviderTests: XCTestCase {
      private let provider = DefaultStarterRoutesProvider()

      func test_loadAll_ucRotaDondurur() {
          let routes = provider.loadAll()
          XCTAssertEqual(routes.count, 3)
          for route in routes {
              XCTAssertGreaterThanOrEqual(route.places.count, 3)
              XCTAssertFalse(route.name.isEmpty)
          }
      }

      func test_loadAll_koordinatlarIstanbulSinirlarinda() {
          for route in provider.loadAll() {
              for place in route.places {
                  XCTAssertTrue((40.8...41.3).contains(place.latitude), place.name)
                  XCTAssertTrue((28.5...29.3).contains(place.longitude), place.name)
              }
          }
      }

      func test_makeSavedRoute_snapshotVeMerkezDogru() {
          guard let def = provider.loadAll().first else {
              return XCTFail("Hazır rota yüklenemedi")
          }
          let saved = provider.makeSavedRoute(from: def)
          XCTAssertEqual(saved.name, def.name)
          XCTAssertEqual(saved.placeSnapshots.count, def.places.count)
          XCTAssertEqual(saved.placeSnapshots.map(\.sortIndex), Array(0..<def.places.count))
          let expectedLat = def.places.map(\.latitude).reduce(0, +) / Double(def.places.count)
          XCTAssertEqual(saved.centerLatitude, expectedLat, accuracy: 0.0001)
      }
  }
  ```

- [ ] **2.8 Lokalizasyon** — 5 dosyaya ekle:
  ```
  // tr.lproj/Localizable.strings
  "Hazır Rotalar" = "Hazır Rotalar";
  "Rotalarıma Ekle" = "Rotalarıma Ekle";
  "Hazır İstanbul rotalarını dene" = "Hazır İstanbul rotalarını dene";
  "Küratörlü yürüyüş rotaları — tek dokunuşla rotalarına ekle." = "Küratörlü yürüyüş rotaları — tek dokunuşla rotalarına ekle.";
  "Keşfetmeye Başla" = "Keşfetmeye Başla";
  ```
  ```
  // en.lproj/Localizable.strings
  "Hazır Rotalar" = "Starter Routes";
  "Rotalarıma Ekle" = "Add to My Routes";
  "Hazır İstanbul rotalarını dene" = "Try ready-made Istanbul routes";
  "Küratörlü yürüyüş rotaları — tek dokunuşla rotalarına ekle." = "Curated walking routes — add them with one tap.";
  "Keşfetmeye Başla" = "Start Exploring";
  ```
  ```
  // es.lproj/Localizable.strings
  "Hazır Rotalar" = "Rutas listas";
  "Rotalarıma Ekle" = "Añadir a mis rutas";
  "Hazır İstanbul rotalarını dene" = "Prueba rutas de Estambul listas";
  "Küratörlü yürüyüş rotaları — tek dokunuşla rotalarına ekle." = "Rutas a pie seleccionadas: añádelas con un toque.";
  "Keşfetmeye Başla" = "Empezar a explorar";
  ```
  ```
  // de.lproj/Localizable.strings
  "Hazır Rotalar" = "Fertige Routen";
  "Rotalarıma Ekle" = "Zu meinen Routen";
  "Hazır İstanbul rotalarını dene" = "Fertige Istanbul-Routen ausprobieren";
  "Küratörlü yürüyüş rotaları — tek dokunuşla rotalarına ekle." = "Kuratierte Spazierrouten – mit einem Tipp hinzufügen.";
  "Keşfetmeye Başla" = "Jetzt entdecken";
  ```
  ```
  // ru.lproj/Localizable.strings
  "Hazır Rotalar" = "Готовые маршруты";
  "Rotalarıma Ekle" = "Добавить в мои маршруты";
  "Hazır İstanbul rotalarını dene" = "Попробуйте готовые маршруты по Стамбулу";
  "Küratörlü yürüyüş rotaları — tek dokunuşla rotalarına ekle." = "Подобранные пешие маршруты — добавьте одним касанием.";
  "Keşfetmeye Başla" = "Начать открывать";
  ```
  (Rota/mekan İSİMLERİ veri olduğu için lokalize edilmez — Türkçe kalır, bu bilinçli.)

- [ ] **2.9 Tam test koşusu** → yeşil.

**Commit:** `feat: hazır İstanbul başlangıç rotaları (bundle JSON + boş ekran kartları)`

---

## FAZ 3 — 🟠 Onboarding'e Swarm Adımı

**Sorun:** En güçlü kanca (Swarm import) Mekanlarım toolbar'ında gömülü.
**Çözüm:** Onboarding'e 4. sayfa. Import mantığı `PlacesListView`'dekiyle aynı desendir
(security-scoped URL + `swarmImporting.parseSwarm` + `placeStore.importPlace`), ama
onboarding'de paywall GÖSTERİLMEZ — ücretsiz limit kadar (20) aktarılır, kalan için not düşülür.

Tüm değişiklikler **`Pinly/Views/OnboardingView.swift`** içinde:

- [ ] **3.1 `OnboardingView` struct'ına property'ler ekle** (`let onFinish` altına):
  ```swift
      @Environment(\.swarmImporting) private var swarmImporting
      @Environment(\.entitlements) private var entitlements
      @Environment(\.modelContext) private var modelContext
      @EnvironmentObject var placeStore: PlaceStore

      @State private var showSwarmPicker = false
      @State private var isImportingSwarm = false
      @State private var swarmImportedCount: Int? = nil
      @State private var swarmTruncated = false
      @State private var swarmError = false
  ```

- [ ] **3.2 TabView'a 4. sayfa** — `ForEach(...)` bloğunun kapanışından sonra,
  `TabView` içinde:
  ```swift
                      SwarmOnboardingPageView(
                          isImporting: isImportingSwarm,
                          importedCount: swarmImportedCount,
                          truncated: swarmTruncated,
                          onPickFile: { showSwarmPicker = true }
                      )
                      .tag(pages.count)
  ```

- [ ] **3.3 Sayfa göstergesi ve butonlar** — toplam sayfa sayısı artık `pages.count + 1`:
  - Gösterge döngüsü: `ForEach(0..<pages.count, ...)` → `ForEach(0..<(pages.count + 1), ...)`
  - "Atla" koşulu: `if page < pages.count - 1` → `if page < pages.count`
  - Alt buton ilerleme koşulu: `if page < pages.count - 1` → `if page < pages.count`
  - Alt buton etiketi: `page < pages.count - 1 ? ... : ...` → `page < pages.count ? NSLocalizedString("Devam Et", ...) : NSLocalizedString("Başla", ...)`

- [ ] **3.4 fileImporter + hata alert'i** — kök `ZStack`'in kapanışından sonra
  (body'de, mevcut modifier'ların yanına):
  ```swift
          .fileImporter(
              isPresented: $showSwarmPicker,
              allowedContentTypes: [.json],
              allowsMultipleSelection: false
          ) { result in
              handleSwarmFile(result)
          }
          .alert(NSLocalizedString("Dosya Okunamadı", comment: ""), isPresented: $swarmError) {
              Button(NSLocalizedString("Tamam", comment: ""), role: .cancel) {}
          } message: {
              Text(NSLocalizedString("Geçerli bir Swarm checkins.json dosyası seçin.", comment: ""))
          }
  ```
  (İki alert metni de mevcut lokalizasyon anahtarları — yenisi gerekmez.)
  Dosyanın başına `import UniformTypeIdentifiers` GEREKMEZ (`.json` SwiftUI'de mevcut);
  derleme hatası çıkarsa ekle.

- [ ] **3.5 Import fonksiyonu** — `OnboardingView` struct'ının sonuna:
  ```swift
      private func handleSwarmFile(_ result: Result<[URL], Error>) {
          guard let url = try? result.get().first,
                url.startAccessingSecurityScopedResource()
          else { swarmError = true; return }
          defer { url.stopAccessingSecurityScopedResource() }
          guard let data = try? Data(contentsOf: url),
                let parsed = swarmImporting.parseSwarm(data: data),
                !parsed.isEmpty
          else { swarmError = true; return }

          // Onboarding'de paywall gösterilmez — ücretsiz limit kadar aktarılır
          let capacity = entitlements.isPro
              ? parsed.count
              : max(0, entitlements.freeLimit - placeStore.places.count)
          let toImport = Array(parsed.prefix(capacity))
          swarmTruncated = parsed.count > toImport.count
          isImportingSwarm = true
          Task {
              for item in toImport {
                  await placeStore.importPlace(item, context: modelContext)
              }
              swarmImportedCount = toImport.count
              isImportingSwarm = false
          }
      }
  ```

- [ ] **3.6 Yeni sayfa view'ı** — dosyanın sonuna (`OnboardingPageView`'ın yanına):
  ```swift
  // MARK: - Swarm İçe Aktarma Sayfası

  private struct SwarmOnboardingPageView: View {
      let isImporting: Bool
      let importedCount: Int?
      let truncated: Bool
      let onPickFile: () -> Void

      var body: some View {
          VStack(spacing: 32) {
              Spacer()

              ZStack {
                  Circle()
                      .stroke(PinlyTheme.gold.opacity(0.10), lineWidth: 1.5)
                      .frame(width: 220, height: 220)
                  Circle()
                      .stroke(PinlyTheme.gold.opacity(0.18), lineWidth: 1.5)
                      .frame(width: 164, height: 164)
                  Circle()
                      .fill(PinlyTheme.gold.opacity(0.12))
                      .frame(width: 128, height: 128)
                  Image(systemName: "square.and.arrow.down.on.square")
                      .font(.system(size: 54, weight: .medium))
                      .foregroundStyle(PinlyTheme.gold)
              }

              VStack(spacing: 14) {
                  Text(NSLocalizedString("Swarm'dan Taşın", comment: ""))
                      .font(.title.bold())
                      .multilineTextAlignment(.center)
                  Text(NSLocalizedString("Foursquare/Swarm geçmişin mi var? checkins.json dosyanı seç, mekanların saniyeler içinde Pinly'de olsun.", comment: ""))
                      .font(.body)
                      .foregroundColor(.secondary)
                      .multilineTextAlignment(.center)
                      .lineSpacing(3)
                      .padding(.horizontal, 36)
              }

              if let count = importedCount {
                  VStack(spacing: 6) {
                      Label(
                          String(format: NSLocalizedString("%lld mekan içe aktarıldı", comment: ""), count),
                          systemImage: "checkmark.circle.fill"
                      )
                      .font(.subheadline.weight(.semibold))
                      .foregroundColor(PinlyTheme.success)
                      if truncated {
                          Text(NSLocalizedString("Ücretsiz sürüm 20 mekanla sınırlı — kalanını Pro ile ekleyebilirsin.", comment: ""))
                              .font(.caption)
                              .foregroundColor(.secondary)
                              .multilineTextAlignment(.center)
                              .padding(.horizontal, 36)
                      }
                  }
              } else if isImporting {
                  ProgressView()
              } else {
                  VStack(spacing: 10) {
                      Button(action: onPickFile) {
                          Label(NSLocalizedString("Swarm Dosyası Seç", comment: ""), systemImage: "doc.badge.arrow.up")
                              .fontWeight(.semibold)
                              .padding(.horizontal, 24)
                              .padding(.vertical, 12)
                              .background(PinlyTheme.gold.opacity(0.12))
                              .foregroundColor(PinlyTheme.gold)
                              .cornerRadius(14)
                      }
                      Text(NSLocalizedString("İpucu: Swarm → Profil → Ayarlar → Verilerimi İndir", comment: ""))
                          .font(.caption2)
                          .foregroundColor(.secondary)
                  }
              }

              Spacer()
              Spacer()
          }
      }
  }
  ```

- [ ] **3.7 Kontrol:** `ContentView`'daki `OnboardingView { ... }` çağrısı değişmez
  (environment'lar PinlyApp'ten miras alınır) — doğrula, dokunma.

- [ ] **3.8 Lokalizasyon** — 5 dosyaya ekle:
  ```
  // tr.lproj — değer = anahtar (5 satır aynen kopyala, sağ tarafı sola eşitle)
  "Swarm'dan Taşın" = "Swarm'dan Taşın";
  "Foursquare/Swarm geçmişin mi var? checkins.json dosyanı seç, mekanların saniyeler içinde Pinly'de olsun." = "Foursquare/Swarm geçmişin mi var? checkins.json dosyanı seç, mekanların saniyeler içinde Pinly'de olsun.";
  "Swarm Dosyası Seç" = "Swarm Dosyası Seç";
  "%lld mekan içe aktarıldı" = "%lld mekan içe aktarıldı";
  "Ücretsiz sürüm 20 mekanla sınırlı — kalanını Pro ile ekleyebilirsin." = "Ücretsiz sürüm 20 mekanla sınırlı — kalanını Pro ile ekleyebilirsin.";
  "İpucu: Swarm → Profil → Ayarlar → Verilerimi İndir" = "İpucu: Swarm → Profil → Ayarlar → Verilerimi İndir";
  ```
  ```
  // en.lproj
  "Swarm'dan Taşın" = "Move In from Swarm";
  "Foursquare/Swarm geçmişin mi var? checkins.json dosyanı seç, mekanların saniyeler içinde Pinly'de olsun." = "Have a Foursquare/Swarm history? Pick your checkins.json and your places land in Pinly in seconds.";
  "Swarm Dosyası Seç" = "Choose Swarm File";
  "%lld mekan içe aktarıldı" = "%lld places imported";
  "Ücretsiz sürüm 20 mekanla sınırlı — kalanını Pro ile ekleyebilirsin." = "The free plan is limited to 20 places — unlock the rest with Pro.";
  "İpucu: Swarm → Profil → Ayarlar → Verilerimi İndir" = "Tip: Swarm → Profile → Settings → Download My Data";
  ```
  ```
  // es.lproj
  "Swarm'dan Taşın" = "Migra desde Swarm";
  "Foursquare/Swarm geçmişin mi var? checkins.json dosyanı seç, mekanların saniyeler içinde Pinly'de olsun." = "¿Tienes historial de Foursquare/Swarm? Elige tu checkins.json y tus lugares estarán en Pinly en segundos.";
  "Swarm Dosyası Seç" = "Elegir archivo de Swarm";
  "%lld mekan içe aktarıldı" = "%lld lugares importados";
  "Ücretsiz sürüm 20 mekanla sınırlı — kalanını Pro ile ekleyebilirsin." = "El plan gratuito se limita a 20 lugares; desbloquea el resto con Pro.";
  "İpucu: Swarm → Profil → Ayarlar → Verilerimi İndir" = "Consejo: Swarm → Perfil → Ajustes → Descargar mis datos";
  ```
  ```
  // de.lproj
  "Swarm'dan Taşın" = "Von Swarm umziehen";
  "Foursquare/Swarm geçmişin mi var? checkins.json dosyanı seç, mekanların saniyeler içinde Pinly'de olsun." = "Du hast eine Foursquare/Swarm-Historie? Wähle deine checkins.json und deine Orte sind in Sekunden in Pinly.";
  "Swarm Dosyası Seç" = "Swarm-Datei wählen";
  "%lld mekan içe aktarıldı" = "%lld Orte importiert";
  "Ücretsiz sürüm 20 mekanla sınırlı — kalanını Pro ile ekleyebilirsin." = "Die Gratisversion ist auf 20 Orte begrenzt – den Rest schaltest du mit Pro frei.";
  "İpucu: Swarm → Profil → Ayarlar → Verilerimi İndir" = "Tipp: Swarm → Profil → Einstellungen → Meine Daten laden";
  ```
  ```
  // ru.lproj
  "Swarm'dan Taşın" = "Перенос из Swarm";
  "Foursquare/Swarm geçmişin mi var? checkins.json dosyanı seç, mekanların saniyeler içinde Pinly'de olsun." = "Есть история Foursquare/Swarm? Выберите файл checkins.json — и ваши места окажутся в Pinly за секунды.";
  "Swarm Dosyası Seç" = "Выбрать файл Swarm";
  "%lld mekan içe aktarıldı" = "Импортировано мест: %lld";
  "Ücretsiz sürüm 20 mekanla sınırlı — kalanını Pro ile ekleyebilirsin." = "Бесплатная версия ограничена 20 местами — остальное доступно в Pro.";
  "İpucu: Swarm → Profil → Ayarlar → Verilerimi İndir" = "Подсказка: Swarm → Профиль → Настройки → Скачать мои данные";
  ```

- [ ] **3.9 Tam test koşusu** → yeşil.

**Commit:** `feat: onboarding'e Swarm içe aktarma adımı eklendi`

---

## FAZ 4 — 🟡 Rota Sırası Optimizasyonu (nearest-neighbor)

**Sorun:** Durak sırası tamamen elle; kötü sıra yürüme mesafesini ikiye katlayabiliyor.
**Çözüm:** Saf nearest-neighbor fonksiyonu + RouteSummaryView'de navigasyon öncesi buton.
Otomatik uygulanmaz — kullanıcının elle sıralamasına saygı, buton opsiyoneldir.

- [ ] **4.1 YENİ dosya `Pinly/Managers/RouteOrderOptimizer.swift`** — aynen:
  ```swift
  import Foundation
  import CoreLocation

  // MARK: - RouteOrderOptimizer

  /// Durak sırasını yürüme mesafesine göre iyileştiren saf yardımcı.
  /// Basit nearest-neighbor — mükemmel TSP değil, ama kötü elle sıralamayı
  /// belirgin biçimde kısaltır. State/framework bağımlılığı yok, test edilebilir.
  enum RouteOrderOptimizer {
      /// `start` verilirse tüm duraklar oradan başlayarak sıralanır.
      /// `start` yoksa ilk durak sabit kalır, kalanlar ona göre dizilir.
      /// Koordinatsız mekanlar sıranın sonuna orijinal sıralarıyla eklenir.
      static func nearestNeighborOrder(places: [Place], start: CLLocationCoordinate2D?) -> [Place] {
          let located = places.filter { $0.coordinate != nil }
          let unlocated = places.filter { $0.coordinate == nil }
          guard located.count >= 2 else { return places }

          var remaining = located
          var ordered: [Place] = []
          var cursor: CLLocationCoordinate2D
          if let start {
              cursor = start
          } else {
              let first = remaining.removeFirst()
              ordered.append(first)
              cursor = first.coordinate!
          }

          while !remaining.isEmpty {
              let nearestIndex = remaining.indices.min(by: { a, b in
                  distance(from: cursor, to: remaining[a].coordinate!)
                      < distance(from: cursor, to: remaining[b].coordinate!)
              })!
              let next = remaining.remove(at: nearestIndex)
              ordered.append(next)
              cursor = next.coordinate!
          }
          return ordered + unlocated
      }

      private static func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> CLLocationDistance {
          CLLocation(latitude: a.latitude, longitude: a.longitude)
              .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
      }
  }
  ```

- [ ] **4.2 `Pinly/Managers/RouteManager.swift`** — `commitCategorySelection()` metodunun
  hemen ALTINA ekle (protokole EKLEME — yalnızca sınıfa; RouteSummaryView somut
  RouteManager kullanıyor):
  ```swift
      /// Durak sırasını aynı mekan kümesiyle değiştirir — yalnızca navigasyon
      /// başlamadan önce (rota verileri çağıran tarafından yeniden hesaplanmalı).
      func applyRouteOrder(_ ordered: [Place]) {
          guard !isNavigating, ordered.count == routePlaces.count else { return }
          routePlaces = ordered
      }
  ```

- [ ] **4.3 `Pinly/Views/RouteSummaryView.swift`** — navigasyon öncesi buton grubunda,
  "Rotayı Kaydet" butonunun `.alert(NSLocalizedString("Rota Kaydedildi!"...)` bloğunun
  KAPANIŞINDAN sonra, "GPX İndir" butonundan ÖNCE ekle:
  ```swift
                    if routeManager.routePlaces.count >= 3 {
                        Button {
                            let optimized = RouteOrderOptimizer.nearestNeighborOrder(
                                places: routeManager.routePlaces,
                                start: locationManager.userLocation?.coordinate
                            )
                            let changed = optimized.map(\.name) != routeManager.routePlaces.map(\.name)
                            routeManager.applyRouteOrder(optimized)
                            if changed { loadRoutes() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                Text(NSLocalizedString("Sırayı Optimize Et", comment: ""))
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(PinlyTheme.gold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(PinlyTheme.gold.opacity(0.10))
                            .cornerRadius(14)
                        }
                    }
  ```
  (`loadRoutes()` bu dosyada zaten var — rota polyline'larını yeniden hesaplar.)

- [ ] **4.4 YENİ test `PinlyTests/RouteOrderOptimizerTests.swift`** — aynen:
  ```swift
  import XCTest
  import CoreLocation
  @testable import Pinly

  @MainActor
  final class RouteOrderOptimizerTests: XCTestCase {
      private func makePlace(_ name: String, lat: Double?, lon: Double?) -> Place {
          let place = Place(name: name, category: "General", address: "", notes: "")
          place.latitude = lat
          place.longitude = lon
          return place
      }

      func test_baslangictanYakinligaGoreSiralar() {
          // Başlangıç (0,0); C en yakın, sonra B, sonra A
          let a = makePlace("A", lat: 0.30, lon: 0)
          let b = makePlace("B", lat: 0.20, lon: 0)
          let c = makePlace("C", lat: 0.10, lon: 0)
          let result = RouteOrderOptimizer.nearestNeighborOrder(
              places: [a, b, c],
              start: CLLocationCoordinate2D(latitude: 0, longitude: 0)
          )
          XCTAssertEqual(result.map(\.name), ["C", "B", "A"])
      }

      func test_baslangicYoksaIlkDurakSabitKalir() {
          let a = makePlace("A", lat: 0.30, lon: 0)
          let b = makePlace("B", lat: 0.10, lon: 0)
          let c = makePlace("C", lat: 0.20, lon: 0)
          let result = RouteOrderOptimizer.nearestNeighborOrder(places: [a, b, c], start: nil)
          XCTAssertEqual(result.first?.name, "A")
          XCTAssertEqual(result.map(\.name), ["A", "C", "B"])
      }

      func test_koordinatsizMekanlarSonaGider() {
          let a = makePlace("A", lat: 0.20, lon: 0)
          let noCoord = makePlace("X", lat: nil, lon: nil)
          let b = makePlace("B", lat: 0.10, lon: 0)
          let result = RouteOrderOptimizer.nearestNeighborOrder(
              places: [a, noCoord, b],
              start: CLLocationCoordinate2D(latitude: 0, longitude: 0)
          )
          XCTAssertEqual(result.map(\.name), ["B", "A", "X"])
          XCTAssertEqual(result.count, 3)
      }

      func test_ikidenAzKonumluMekandaDokunmaz() {
          let a = makePlace("A", lat: 0.10, lon: 0)
          let x = makePlace("X", lat: nil, lon: nil)
          let result = RouteOrderOptimizer.nearestNeighborOrder(
              places: [x, a],
              start: CLLocationCoordinate2D(latitude: 0, longitude: 0)
          )
          XCTAssertEqual(result.map(\.name), ["X", "A"])
      }
  }
  ```
  Not: `Place` init imzası farklıysa (`notes` parametresi yoksa vb.)
  `PinlyTests/` altındaki mevcut testlerde kullanılan Place kurulumunu birebir kopyala.

- [ ] **4.5 Lokalizasyon** — 5 dosyaya ekle:
  ```
  // tr: "Sırayı Optimize Et" = "Sırayı Optimize Et";
  // en: "Sırayı Optimize Et" = "Optimize Order";
  // es: "Sırayı Optimize Et" = "Optimizar orden";
  // de: "Sırayı Optimize Et" = "Reihenfolge optimieren";
  // ru: "Sırayı Optimize Et" = "Оптимизировать порядок";
  ```

- [ ] **4.6 Tam test koşusu** → yeşil.

**Commit:** `feat: rota durak sırası nearest-neighbor ile optimize edilebiliyor`

---

## FAZ 5 — 🟡 Gün Serisi (Streak) Koruma Bildirimi

**Sorun:** Tek bildirim var (Pazar raporu). Serisini kaybetmek üzere olan kullanıcıya
hatırlatma yok. **Desen:** her uygulama açılışında "yarın 20:00" için tek seferlik
bildirim kur (aynı ID ile öncekini iptal ederek). Kullanıcı ertesi gün uygulamayı
açarsa bildirim ileri kayar → yalnızca girmediği gün akşamı tetiklenir.

- [ ] **5.1 Kontrol:** `grep -rn ": NotificationScheduling" Pinly PinlyTests` —
  yalnızca `DefaultNotificationScheduler` çıkmalı. Başka conformer varsa ona da
  5.2'deki yeni metodu (boş gövdeyle) ekle.

- [ ] **5.2 `Pinly/Managers/WeeklyReportManager.swift`** — protokole metod ekle:
  ```swift
  protocol NotificationScheduling {
      /// Pazar sabahı 09:00 tekrarlayan lokal bildirim planlar.
      func scheduleWeeklyNotification()
      /// Seri 2+ günse ertesi akşam 20:00 için tek seferlik hatırlatma kurar;
      /// her çağrıda önceki kurulumu iptal eder (seri kırıldıysa bildirim de düşer).
      func scheduleStreakReminder(consecutiveDays: Int)
  }
  ```
  ve `DefaultNotificationScheduler`'a implementasyon (mevcut metodun altına):
  ```swift
      func scheduleStreakReminder(consecutiveDays: Int) {
          let center = UNUserNotificationCenter.current()
          center.removePendingNotificationRequests(withIdentifiers: ["pinly.streakReminder"])
          guard consecutiveDays >= 2 else { return }

          let content   = UNMutableNotificationContent()
          content.title = NSLocalizedString("🔥 Serin bozulmasın!", comment: "")
          content.body  = String(
              format: NSLocalizedString("%lld günlük serin var — bugün kısa bir rota yürü ya da yeni bir mekan kaydet.", comment: ""),
              consecutiveDays
          )
          content.sound = .default

          guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) else { return }
          var comps    = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
          comps.hour   = 20
          comps.minute = 0

          let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
          center.add(UNNotificationRequest(
              identifier: "pinly.streakReminder",
              content: content,
              trigger: trigger
          ))
      }
  ```

- [ ] **5.3 `Pinly/PinlyApp.swift`** — `init()` içinde,
  `DefaultBadgeService.shared.recordAppOpen()` satırının hemen ALTINA ekle:
  ```swift
          // Seri koruma: yarın akşam için hatırlatma (kullanıcı yarın girerse ileri kayar)
          if UserDefaults.standard.bool(forKey: "pinly.hasSeenOnboarding") {
              notificationScheduler.scheduleStreakReminder(
                  consecutiveDays: DefaultBadgeService.shared.consecutiveDays
              )
          }
  ```

- [ ] **5.4 Lokalizasyon** — 5 dosyaya ekle:
  ```
  // tr.lproj
  "🔥 Serin bozulmasın!" = "🔥 Serin bozulmasın!";
  "%lld günlük serin var — bugün kısa bir rota yürü ya da yeni bir mekan kaydet." = "%lld günlük serin var — bugün kısa bir rota yürü ya da yeni bir mekan kaydet.";
  ```
  ```
  // en.lproj
  "🔥 Serin bozulmasın!" = "🔥 Don't break your streak!";
  "%lld günlük serin var — bugün kısa bir rota yürü ya da yeni bir mekan kaydet." = "You're on a %lld-day streak — walk a short route or save a new place today.";
  ```
  ```
  // es.lproj
  "🔥 Serin bozulmasın!" = "🔥 ¡No rompas tu racha!";
  "%lld günlük serin var — bugün kısa bir rota yürü ya da yeni bir mekan kaydet." = "Llevas una racha de %lld días: camina una ruta corta o guarda un lugar nuevo hoy.";
  ```
  ```
  // de.lproj
  "🔥 Serin bozulmasın!" = "🔥 Lass deine Serie nicht reißen!";
  "%lld günlük serin var — bugün kısa bir rota yürü ya da yeni bir mekan kaydet." = "Du hast eine Serie von %lld Tagen – geh heute eine kurze Route oder speichere einen neuen Ort.";
  ```
  ```
  // ru.lproj
  "🔥 Serin bozulmasın!" = "🔥 Не прерывайте серию!";
  "%lld günlük serin var — bugün kısa bir rota yürü ya da yeni bir mekan kaydet." = "У вас серия %lld дней — пройдите короткий маршрут или сохраните новое место сегодня.";
  ```

- [ ] **5.5 Tam test koşusu** → yeşil.

**Commit:** `feat: gün serisi koruma bildirimi (ertesi akşam 20:00 hatırlatma)`

---

## FAZ 6 — 🟡 Yakınında Keşfet (MKLocalSearch)

**Sorun:** Keşfet sekmesi yalnızca kullanıcının kendi eklediklerini gösteriyor.
**Çözüm:** MKLocalSearch ile "yakınımda kafeler/müzeler" → tek dokunuşla Pinly'ye ekleme.
Freemium gate (`canAddPlace`) uygulanır.

- [ ] **6.1 `Pinly/Services/GeocodingService.swift`** — dosyanın sonuna ekle
  (dosyada `MapKit` import'u yoksa başa `import MapKit` ekle):
  ```swift
  // MARK: - NearbySearching

  struct NearbyPlaceResult: Identifiable, Equatable {
      let id = UUID()
      let name: String
      let address: String
      let latitude: Double
      let longitude: Double
  }

  /// Kullanıcının çevresindeki POI araması (MKLocalSearch) — Keşfet/Yakınında için.
  protocol NearbySearching: AnyObject {
      func searchNearby(query: String, around coordinate: CLLocationCoordinate2D) async -> [NearbyPlaceResult]
  }

  final class DefaultNearbySearchService: NearbySearching {
      static let shared = DefaultNearbySearchService()

      func searchNearby(query: String, around coordinate: CLLocationCoordinate2D) async -> [NearbyPlaceResult] {
          let request = MKLocalSearch.Request()
          request.naturalLanguageQuery = query
          request.resultTypes = .pointOfInterest
          request.region = MKCoordinateRegion(
              center: coordinate,
              latitudinalMeters: 3000,
              longitudinalMeters: 3000
          )
          guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
          return response.mapItems.compactMap { item in
              guard let name = item.name else { return nil }
              let c = item.placemark.coordinate
              return NearbyPlaceResult(
                  name: name,
                  address: item.placemark.title ?? "",
                  latitude: c.latitude,
                  longitude: c.longitude
              )
          }
      }
  }
  ```

- [ ] **6.2 `Pinly/Services/ServiceEnvironment.swift`** — Faz 2.3 deseniyle
  `NearbySearchKey` (default: `DefaultNearbySearchService.shared`) ve
  `var nearbySearch: NearbySearching` ekle.
  **`Pinly/PinlyApp.swift`** — `private let nearbySearchService = DefaultNearbySearchService.shared`
  + `.environment(\.nearbySearch, nearbySearchService)`.

- [ ] **6.3 YENİ dosya `Pinly/Views/NearbyPlacesViewModel.swift`** — aynen:
  ```swift
  import Foundation
  import CoreLocation
  import SwiftData

  // MARK: - NearbyPlacesViewModel

  @MainActor
  final class NearbyPlacesViewModel: ObservableObject {
      @Published var results: [NearbyPlaceResult] = []
      @Published var isSearching = false
      @Published var selectedCategory: PlaceCategory = .cafe
      @Published var addedNames: Set<String> = []

      private let nearbySearch: NearbySearching
      private let entitlements: EntitlementProviding

      init(
          nearbySearch: NearbySearching = DefaultNearbySearchService.shared,
          entitlements: EntitlementProviding = LocalEntitlementService.shared
      ) {
          self.nearbySearch = nearbySearch
          self.entitlements = entitlements
      }

      /// Kategori → MKLocalSearch sorgusu (TR pazarı; Apple çok dilli eşleştirir).
      static func query(for category: PlaceCategory) -> String {
          switch category {
          case .restaurant: return "restoran"
          case .cafe:       return "kafe"
          case .park:       return "park"
          case .museum:     return "müze"
          case .historical: return "tarihi yer"
          case .library:    return "kütüphane"
          case .dessert:    return "tatlıcı"
          case .general:    return "gezilecek yer"
          }
      }

      func search(around coordinate: CLLocationCoordinate2D) async {
          isSearching = true
          results = await nearbySearch.searchNearby(
              query: Self.query(for: selectedCategory),
              around: coordinate
          )
          isSearching = false
      }

      /// false dönerse çağıran paywall göstermeli.
      func add(_ result: NearbyPlaceResult, placeStore: PlaceStore, context: ModelContext) async -> Bool {
          guard entitlements.canAddPlace(currentCount: placeStore.places.count) else { return false }
          await placeStore.addPlace(
              name: result.name,
              category: selectedCategory.rawValue,
              address: result.address,
              notes: "",
              coordinate: CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude),
              context: context
          )
          addedNames.insert(result.name)
          return true
      }
  }
  ```

- [ ] **6.4 YENİ dosya `Pinly/Views/NearbyPlacesView.swift`** — aynen:
  ```swift
  import SwiftUI
  import CoreLocation

  // MARK: - Yakınında Keşfet

  struct NearbyPlacesView: View {
      @Environment(\.modelContext) private var modelContext
      @EnvironmentObject var placeStore: PlaceStore
      @EnvironmentObject var locationManager: LocationManager

      @StateObject private var viewModel = NearbyPlacesViewModel()
      @State private var showPaywall = false

      var body: some View {
          VStack(spacing: 0) {
              categoryChips
              content
          }
          .background(PinlyTheme.groundGradient)
          .navigationTitle(NSLocalizedString("Yakınında Keşfet", comment: ""))
          .navigationBarTitleDisplayMode(.inline)
          .sheet(isPresented: $showPaywall) {
              PaywallView { showPaywall = false }
          }
          .task { await searchIfPossible() }
          .onChange(of: viewModel.selectedCategory) {
              Task { await searchIfPossible() }
          }
      }

      private func searchIfPossible() async {
          guard let coordinate = locationManager.userLocation?.coordinate else { return }
          await viewModel.search(around: coordinate)
      }

      private var categoryChips: some View {
          ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                  ForEach(PlaceCategory.allCases, id: \.rawValue) { category in
                      Button {
                          viewModel.selectedCategory = category
                      } label: {
                          Label(category.localizedName, systemImage: category.icon)
                              .font(.caption.weight(.semibold))
                              .padding(.horizontal, 12)
                              .padding(.vertical, 8)
                              .background(
                                  viewModel.selectedCategory == category
                                      ? PinlyTheme.primary
                                      : PinlyTheme.fillMuted
                              )
                              .foregroundColor(
                                  viewModel.selectedCategory == category ? .white : .primary
                              )
                              .cornerRadius(20)
                      }
                  }
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 12)
          }
      }

      @ViewBuilder
      private var content: some View {
          if locationManager.userLocation == nil {
              messageState(
                  icon: "location.slash",
                  text: NSLocalizedString("Konum alınamadı — konum izni verildiğinden emin ol.", comment: "")
              )
          } else if viewModel.isSearching {
              VStack(spacing: 12) {
                  ProgressView()
                  Text(NSLocalizedString("Aranıyor…", comment: ""))
                      .font(.subheadline)
                      .foregroundColor(.secondary)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if viewModel.results.isEmpty {
              messageState(
                  icon: "magnifyingglass",
                  text: NSLocalizedString("Sonuç bulunamadı", comment: "")
              )
          } else {
              List(viewModel.results) { result in
                  NearbyResultRow(
                      result: result,
                      isAdded: viewModel.addedNames.contains(result.name)
                          || placeStore.places.contains { $0.name == result.name }
                  ) {
                      Task {
                          let ok = await viewModel.add(result, placeStore: placeStore, context: modelContext)
                          if !ok { showPaywall = true }
                      }
                  }
                  .listRowBackground(PinlyTheme.surface)
              }
              .listStyle(.insetGrouped)
              .scrollContentBackground(.hidden)
          }
      }

      private func messageState(icon: String, text: String) -> some View {
          VStack(spacing: 14) {
              Image(systemName: icon)
                  .font(.system(size: 44))
                  .foregroundColor(.secondary)
              Text(text)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 40)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
  }

  // MARK: - Sonuç Satırı

  private struct NearbyResultRow: View {
      let result: NearbyPlaceResult
      let isAdded: Bool
      let onAdd: () -> Void

      var body: some View {
          HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 3) {
                  Text(result.name)
                      .font(.subheadline)
                      .fontWeight(.medium)
                      .lineLimit(1)
                  Text(result.address)
                      .font(.caption)
                      .foregroundColor(.secondary)
                      .lineLimit(1)
              }
              Spacer()
              if isAdded {
                  Label(NSLocalizedString("Eklendi", comment: ""), systemImage: "checkmark.circle.fill")
                      .font(.caption.weight(.semibold))
                      .foregroundColor(PinlyTheme.success)
                      .labelStyle(.titleAndIcon)
              } else {
                  Button(action: onAdd) {
                      Text(NSLocalizedString("Ekle", comment: ""))
                          .font(.caption.weight(.semibold))
                          .padding(.horizontal, 14)
                          .padding(.vertical, 7)
                          .background(PinlyTheme.primary)
                          .foregroundColor(.white)
                          .cornerRadius(14)
                  }
                  .buttonStyle(.plain)
              }
          }
          .padding(.vertical, 2)
      }
  }
  ```

- [ ] **6.5 `Pinly/Views/DiscoverView.swift`** — giriş kartı. Struct içine ekle:
  ```swift
      private var nearbyCard: some View {
          NavigationLink {
              NearbyPlacesView()
                  .environmentObject(placeStore)
                  .environmentObject(locationManager)
          } label: {
              HStack(spacing: 12) {
                  ZStack {
                      RoundedRectangle(cornerRadius: 12)
                          .fill(PinlyTheme.primary.opacity(0.12))
                          .frame(width: 44, height: 44)
                      Image(systemName: "location.magnifyingglass")
                          .foregroundColor(PinlyTheme.primary)
                          .font(.title3)
                  }
                  VStack(alignment: .leading, spacing: 3) {
                      Text(NSLocalizedString("Yakınında Keşfet", comment: ""))
                          .font(.headline)
                          .foregroundColor(.primary)
                      Text(NSLocalizedString("Çevrendeki kafeleri, müzeleri ve daha fazlasını bul, tek dokunuşla ekle.", comment: ""))
                          .font(.caption)
                          .foregroundColor(.secondary)
                          .multilineTextAlignment(.leading)
                  }
                  Spacer()
                  Image(systemName: "chevron.right")
                      .font(.caption)
                      .foregroundColor(.secondary)
              }
              .padding(14)
              .background(PinlyTheme.surface)
              .cornerRadius(16)
          }
          .buttonStyle(.plain)
          .padding(.horizontal, 20)
      }
  ```
  ve iki yere yerleştir:
  - Dolu dal: `ScrollView` içindeki `VStack(spacing: 20)`'de `statsBar`'dan ÖNCE `nearbyCard`.
  - Boş dal (`placeStore.places.isEmpty`): mevcut `VStack(spacing: 16)`'nın son
    Text'inden SONRA `nearbyCard.padding(.top, 8)`.

- [ ] **6.6 YENİ mock `PinlyTests/Mocks/MockNearbySearching.swift`** — aynen:
  ```swift
  import CoreLocation
  @testable import Pinly

  final class MockNearbySearching: NearbySearching {
      var stubResults: [NearbyPlaceResult] = []
      private(set) var lastQuery: String?

      func searchNearby(query: String, around coordinate: CLLocationCoordinate2D) async -> [NearbyPlaceResult] {
          lastQuery = query
          return stubResults
      }
  }
  ```

- [ ] **6.7 YENİ test `PinlyTests/NearbyPlacesViewModelTests.swift`** — aşağıdaki
  iskeleti kullan; PlaceStore + in-memory ModelContext kurulumunu
  `PinlyTests/AddPlaceViewModelTests.swift`'teki mevcut desenle birebir aynı yap:
  ```swift
  import XCTest
  import CoreLocation
  @testable import Pinly

  @MainActor
  final class NearbyPlacesViewModelTests: XCTestCase {

      func test_search_sonuclariDoldururVeDogruSorguyuKullanir() async {
          let mock = MockNearbySearching()
          mock.stubResults = [
              NearbyPlaceResult(name: "Test Kafe", address: "Adres", latitude: 41, longitude: 29)
          ]
          let vm = NearbyPlacesViewModel(nearbySearch: mock, entitlements: MockEntitlementProviding())
          vm.selectedCategory = .cafe

          await vm.search(around: CLLocationCoordinate2D(latitude: 41, longitude: 29))

          XCTAssertEqual(vm.results.map(\.name), ["Test Kafe"])
          XCTAssertEqual(mock.lastQuery, "kafe")
          XCTAssertFalse(vm.isSearching)
      }

      func test_add_limitDoluysaFalseDonerVeEklemez() async {
          // MockEntitlementProviding'i canAddPlace false dönecek şekilde ayarla
          // (mock'un mevcut API'sine bak: isPro=false + freeLimit'i aşan sayaç,
          //  ya da varsa doğrudan stub alanı)
          // ... AddPlaceViewModelTests'teki PlaceStore/ModelContext kurulumunu kopyala ...
          // let ok = await vm.add(result, placeStore: store, context: context)
          // XCTAssertFalse(ok)
          // XCTAssertTrue(vm.addedNames.isEmpty)
      }
  }
  ```
  İkinci testin gövdesini mock'un GERÇEK API'sine göre doldur
  (`PinlyTests/Mocks/MockEntitlementProviding.swift`'i oku) — davranış beklentisi
  yorumlardaki gibi: gate kapalıyken `false` döner, hiçbir şey eklenmez.

- [ ] **6.8 Lokalizasyon** — 5 dosyaya ekle. ÖNCE kontrol:
  `grep -n '"Ekle"' Pinly/en.lproj/Localizable.strings` — anahtar zaten varsa
  "Ekle" satırını ATLA (duplicate key koyma). Diğerleri:
  ```
  // tr.lproj (değer = anahtar)
  "Yakınında Keşfet" = "Yakınında Keşfet";
  "Çevrendeki kafeleri, müzeleri ve daha fazlasını bul, tek dokunuşla ekle." = "Çevrendeki kafeleri, müzeleri ve daha fazlasını bul, tek dokunuşla ekle.";
  "Sonuç bulunamadı" = "Sonuç bulunamadı";
  "Konum alınamadı — konum izni verildiğinden emin ol." = "Konum alınamadı — konum izni verildiğinden emin ol.";
  "Aranıyor…" = "Aranıyor…";
  "Eklendi" = "Eklendi";
  "Ekle" = "Ekle";
  ```
  ```
  // en.lproj
  "Yakınında Keşfet" = "Discover Nearby";
  "Çevrendeki kafeleri, müzeleri ve daha fazlasını bul, tek dokunuşla ekle." = "Find cafés, museums and more around you — add them with one tap.";
  "Sonuç bulunamadı" = "No results found";
  "Konum alınamadı — konum izni verildiğinden emin ol." = "Couldn't get your location — make sure location permission is granted.";
  "Aranıyor…" = "Searching…";
  "Eklendi" = "Added";
  "Ekle" = "Add";
  ```
  ```
  // es.lproj
  "Yakınında Keşfet" = "Descubre cerca";
  "Çevrendeki kafeleri, müzeleri ve daha fazlasını bul, tek dokunuşla ekle." = "Encuentra cafés, museos y más a tu alrededor; añádelos con un toque.";
  "Sonuç bulunamadı" = "No se encontraron resultados";
  "Konum alınamadı — konum izni verildiğinden emin ol." = "No se pudo obtener tu ubicación; asegúrate de haber concedido el permiso.";
  "Aranıyor…" = "Buscando…";
  "Eklendi" = "Añadido";
  "Ekle" = "Añadir";
  ```
  ```
  // de.lproj
  "Yakınında Keşfet" = "In der Nähe entdecken";
  "Çevrendeki kafeleri, müzeleri ve daha fazlasını bul, tek dokunuşla ekle." = "Finde Cafés, Museen und mehr in deiner Nähe – mit einem Tipp hinzufügen.";
  "Sonuç bulunamadı" = "Keine Ergebnisse gefunden";
  "Konum alınamadı — konum izni verildiğinden emin ol." = "Standort nicht verfügbar – prüfe die Standortberechtigung.";
  "Aranıyor…" = "Suche läuft…";
  "Eklendi" = "Hinzugefügt";
  "Ekle" = "Hinzufügen";
  ```
  ```
  // ru.lproj
  "Yakınında Keşfet" = "Рядом с вами";
  "Çevrendeki kafeleri, müzeleri ve daha fazlasını bul, tek dokunuşla ekle." = "Найдите кафе, музеи и многое другое поблизости — добавьте одним касанием.";
  "Sonuç bulunamadı" = "Ничего не найдено";
  "Konum alınamadı — konum izni verildiğinden emin ol." = "Не удалось получить геопозицию — проверьте разрешение на доступ.";
  "Aranıyor…" = "Поиск…";
  "Eklendi" = "Добавлено";
  "Ekle" = "Добавить";
  ```

- [ ] **6.9 Tam test koşusu** → yeşil.

**Commit:** `feat: Keşfet'e MKLocalSearch tabanlı Yakınında Keşfet eklendi`

---

## FAZ 7 — 🟡 MetricKit Tanılama (görünürlük — hesapsız)

**Sorun:** Crash/hang görünürlüğü sıfır. **Çözüm:** MetricKit — hesap, SDK, network
gerektirmez. Tanılama yükleri Documents'a JSON yazılır, Profil'den paylaşılabilir.
(Firebase/Sentry Apple Developer hesabı fazında değerlendirilecek — şimdi DEĞİL.)

- [ ] **7.1 YENİ dosya `Pinly/Services/DiagnosticsService.swift`** — aynen:
  ```swift
  import Foundation
  import MetricKit

  // MARK: - DiagnosticsCollector

  /// MetricKit tanılama yüklerini (crash, hang, disk yazma taşması) Documents/Diagnostics
  /// altına JSON olarak biriktirir — hesap/SDK gerektirmeyen görünürlük katmanı.
  /// Not: Sistem yükleri en fazla günde bir kez ve yalnızca gerçek cihazda teslim eder.
  final class DiagnosticsCollector: NSObject, MXMetricManagerSubscriber {
      static let shared = DiagnosticsCollector()

      private static var directory: URL {
          FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
              .appendingPathComponent("Diagnostics", isDirectory: true)
      }

      func start() {
          MXMetricManager.shared.add(self)
      }

      func didReceive(_ payloads: [MXDiagnosticPayload]) {
          let dir = Self.directory
          try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          let stamp = ISO8601DateFormatter().string(from: .now)
          for (index, payload) in payloads.enumerated() {
              let url = dir.appendingPathComponent("diagnostic-\(stamp)-\(index).json")
              try? payload.jsonRepresentation().write(to: url)
          }
      }

      static func storedReports() -> [URL] {
          (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
              .filter { $0.pathExtension == "json" }
              .sorted { $0.lastPathComponent > $1.lastPathComponent } ?? []
      }
  }
  ```

- [ ] **7.2 `Pinly/PinlyApp.swift`** — `init()` içinde `MobileAds.shared.start { _ in }`
  satırının hemen ALTINA: `DiagnosticsCollector.shared.start()`

- [ ] **7.3 YENİ dosya `Pinly/Views/DiagnosticsView.swift`** — aynen:
  ```swift
  import SwiftUI

  // MARK: - Tanılama Kayıtları

  struct DiagnosticsView: View {
      private let reports = DiagnosticsCollector.storedReports()

      var body: some View {
          NavigationStack {
              Group {
                  if reports.isEmpty {
                      VStack(spacing: 12) {
                          Image(systemName: "checkmark.seal.fill")
                              .font(.system(size: 44))
                              .foregroundColor(PinlyTheme.success)
                          Text(NSLocalizedString("Henüz tanılama kaydı yok — güzel haber!", comment: ""))
                              .font(.subheadline)
                              .foregroundColor(.secondary)
                              .multilineTextAlignment(.center)
                              .padding(.horizontal, 40)
                      }
                      .frame(maxWidth: .infinity, maxHeight: .infinity)
                  } else {
                      List(reports, id: \.self) { url in
                          ShareLink(item: url) {
                              HStack(spacing: 10) {
                                  Image(systemName: "doc.text")
                                      .foregroundColor(PinlyTheme.primary)
                                  Text(url.lastPathComponent)
                                      .font(.caption)
                                      .lineLimit(1)
                                  Spacer()
                                  Image(systemName: "square.and.arrow.up")
                                      .font(.caption)
                                      .foregroundColor(.secondary)
                              }
                          }
                          .listRowBackground(PinlyTheme.surface)
                      }
                      .listStyle(.insetGrouped)
                      .scrollContentBackground(.hidden)
                  }
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(PinlyTheme.groundGradient)
              .navigationTitle(NSLocalizedString("Tanılama Kayıtları", comment: ""))
              .navigationBarTitleDisplayMode(.inline)
          }
      }
  }
  ```

- [ ] **7.4 `Pinly/Views/home/ProfileTab.swift`** — üç değişiklik:
  (a) State ekle (diğer `@State`'lerin yanına): `@State private var showDiagnostics = false`
  (b) "Hakkında / Destek / Veri" Section'ında "Destek" butonunun `.buttonStyle(.plain)`
  satırından SONRA, "Tüm Verilerimi Sil" butonundan ÖNCE ekle:
  ```swift
                    Button {
                        showDiagnostics = true
                    } label: {
                        HStack(spacing: 14) {
                            settingsIcon("waveform.path.ecg", color: PinlyTheme.gold)
                            Text(NSLocalizedString("Tanılama Kayıtları", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
  ```
  (c) Diğer `.sheet`'lerin yanına (örn. `showStats` sheet'inden sonra):
  ```swift
          .sheet(isPresented: $showDiagnostics) {
              DiagnosticsView()
          }
  ```

- [ ] **7.5 Lokalizasyon** — 5 dosyaya ekle:
  ```
  // tr.lproj
  "Tanılama Kayıtları" = "Tanılama Kayıtları";
  "Henüz tanılama kaydı yok — güzel haber!" = "Henüz tanılama kaydı yok — güzel haber!";
  ```
  ```
  // en.lproj
  "Tanılama Kayıtları" = "Diagnostic Reports";
  "Henüz tanılama kaydı yok — güzel haber!" = "No diagnostic reports yet — good news!";
  ```
  ```
  // es.lproj
  "Tanılama Kayıtları" = "Informes de diagnóstico";
  "Henüz tanılama kaydı yok — güzel haber!" = "Aún no hay informes de diagnóstico. ¡Buenas noticias!";
  ```
  ```
  // de.lproj
  "Tanılama Kayıtları" = "Diagnoseberichte";
  "Henüz tanılama kaydı yok — güzel haber!" = "Noch keine Diagnoseberichte – gute Nachrichten!";
  ```
  ```
  // ru.lproj
  "Tanılama Kayıtları" = "Отчёты диагностики";
  "Henüz tanılama kaydı yok — güzel haber!" = "Отчётов диагностики пока нет — хорошая новость!";
  ```

- [ ] **7.6 Tam test koşusu** → yeşil.
  (Simülatör MetricKit yükü üretmez — doğrulama build+test'le sınırlıdır; bu normaldir.)

**Commit:** `feat: MetricKit tanılama toplayıcı + profil ekranında kayıt görüntüleme`

---

## FAZ 8 — Kapanış: Dokümantasyon

- [ ] **8.1 `CLAUDE.md` güncelle:**
  - "Yapılanlar" listesine ekle: arka plan navigasyonu, hazır İstanbul rotaları,
    onboarding Swarm adımı, rota sırası optimizasyonu, streak bildirimi,
    Yakınında Keşfet, MetricKit tanılama.
  - "Yapılacaklar → Apple Developer olmadan yapılabilecekler" listesinden ŞU
    maddeleri sil: "Haritada Keşfet modu…" (kısmen — Yakınında Keşfet yapıldı;
    'gitmediklerim filtresi' kalabilir, maddeyi ona daralt), "Hazır İstanbul rota
    paketleri…".
  - `Pinly/Services/` tablosuna `StarterRouteService.swift`, `DiagnosticsService.swift`
    ve `GeocodingService.swift` satırına `NearbySearching` notu ekle.
  - `LocationManager.swift` satırına "navigasyonda arka plan konum güncellemeleri
    (`allowsBackgroundLocationUpdates`, UIBackgroundModes: location)" notu ekle.
  - `WeeklyReportManager.swift` satırına "streak hatırlatma bildirimi
    (`scheduleStreakReminder`, ertesi gün 20:00, `pinly.streakReminder`)" notu ekle.
- [ ] **8.2 Bu dosyada (`SPRINT_PLAN.md`) tamamlanan kutucukları `[x]` yap.**
- [ ] **8.3 Tam test koşusu** → yeşil.

**Commit:** `docs: büyüme sprinti sonrası CLAUDE.md ve SPRINT_PLAN güncellendi`

---

## Bilinçli OLARAK kapsam dışı (yapma)

- RevenueCat/paywall gerçek satın alma — Apple Developer hesabı fazı.
- AdMob gerçek ID'ler — Apple Developer hesabı fazı.
- Geofence ("kaydettiğin mekanın yakınındasın") bildirimi — büyük iş, ayrı plan.
- Firebase/Sentry — MetricKit şimdilik yeterli; TestFlight öncesi ayrıca ele alınacak.
- `SavedPlaceSnapshot.placeId` migration'ı — bu sprintte değil.
