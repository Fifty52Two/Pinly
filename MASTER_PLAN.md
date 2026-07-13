# PINLY MASTER PLAN — "Tatlı Proje" Operasyonu

> **Bu belge nedir:** Pinly'yi bugünkü halinden (sağlam ama hijyen borçlu) yayınlanabilir,
> test güvenceli, temiz isimlendirilmiş bir projeye taşıyan uçtan uca uygulama planı.
> Her görev; amaç, kesin adımlar, kod parçaları, doğrulama komutu ve commit mesajıyla yazıldı.
> **Bu planı uygulayan model, adımları sırayla ve fazları atlamadan yürütmelidir.**

---

## 0. YÜRÜTÜCÜ İÇİN KURALLAR (önce oku, her fazda geçerli)

1. **Fazlar sıralıdır.** Bir fazın "Doğrulama" bölümü yeşil olmadan sonrakine geçme.
   Doğrulama kırmızıysa: düzelt → tekrar doğrula → sonra ilerle.
2. **SourceKit "Cannot find X in scope" hataları FALSE POSITIVE'dir** (CLAUDE.md'de de yazar).
   Gerçek doğrulama SADECE `xcodebuild` çıktısıdır. SourceKit hatası için kod değiştirme.
3. **Ana doğrulama komutu** (her fazın sonunda çalıştır):
   ```bash
   xcodebuild build -project Pinly.xcodeproj -scheme Pinly \
     -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
   ```
   `iPhone 16` yoksa mevcut simülatörü bul: `xcrun simctl list devices available | grep iPhone`
   ve komuttaki adı onunla değiştir. Faz 3'ten itibaren `build` yerine `test` kullan.
4. **Test hedefi eklendikten sonra (Faz 3+)** her fazın doğrulaması:
   ```bash
   xcodebuild test -project Pinly.xcodeproj -scheme Pinly \
     -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30
   ```
5. **Her faz = 1 commit** (Faz 5 görev başına 1 commit). Mesaj formatı aşağıda her fazda hazır.
   Commit'lemeden önce `git status` ile beklenmedik dosya olup olmadığına bak.
6. **Tasarım kuralları:** YEŞİL RENK KULLANILMAZ (kullanıcı kararı). Renkler daima
   `Pinly/design/Theme.swift`'ten (`PinlyTheme.*`) alınır, hardcode edilmez.
7. **Yeni/değişen her kullanıcı metni** `NSLocalizedString` ile yazılır ve **5 dile birden**
   eklenir: `tr/en/es/de/ru.lproj/Localizable.strings`. Tek dile ekleyip geçme.
8. **Xcode GUI gerektiren adımlar** 🖱 işaretiyle yazıldı — bunları kullanıcıdan iste
   (terminal'den pbxproj elle düzenlemek sadece açıkça belirtilen tek satırlık yerlerde yapılır).
9. **Bir görevde kararsız kalırsan** görevi atlama; bu belgede "Risk / dikkat" notunu oku,
   hâlâ belirsizse kullanıcıya tek cümlelik soru sor.
10. Faz bitince bu dosyadaki ilgili kutuları `[x]` yap — plan aynı zamanda ilerleme takibidir.

---

## FAZ 0 — Güvenlik Ağı (≈15 dk, risk: yok)

**Amaç:** Mevcut çalışır durumu kayıt altına almak; sonraki her şey buna göre ölçülür.

- [x] **0.1 Bekleyen değişiklikleri commit'le.** Şu an working tree'de 3 dosya değişik:
  `Pinly/model/Place.swift`, `Pinly/view/home/MainTab.swift`, `Pinly/view/home/MoreTab.swift`.
  Önce `git diff` ile bak, UI düzenlemesi olduklarını doğrula, sonra:
  ```bash
  git add -A && git commit -m "chore: bekleyen UI düzenlemeleri (MainTab/MoreTab/Place)"
  ```
- [x] **0.2 Baseline build al.** Kural 3'teki build komutunu çalıştır. `BUILD SUCCEEDED`
  görmeden Faz 1'e geçme. Başarısızsa önce onu düzelt (bu plana başlamadan proje kırıksa
  kullanıcıya bildir).
- [x] **0.3 Çalışma dalı aç:**
  ```bash
  git checkout -b tidy/master-plan
  ```
  Her faz bu dalda commit'lenir; plan bitince kullanıcı onayıyla `main`'e merge edilir.

**Doğrulama:** `git status` temiz + `BUILD SUCCEEDED`.

---

## FAZ 1 — Çöp Temizliği (≈20 dk, risk: düşük)

**Amaç:** Repoda ne varsa gerçek; ölü dosya, artık, şablon kalıntısı yok.

- [x] **1.1 Eski proje artığını sil:**
  ```bash
  git rm -r NotionGO.xcodeproj
  ```
- [x] **1.2 Python artığını sil ve bir daha gelmesini engelle:**
  ```bash
  git rm -r --cached __pycache__ 2>/dev/null; rm -rf __pycache__
  printf '\n__pycache__/\n*.pyc\n' >> .gitignore
  ```
- [x] **1.3 LiveActivity şablon artıklarını sil.** Bu 3 dosya Xcode şablonundan kalma,
  bundle'a kayıtlı değiller ama synchronized folder yüzünden her build'de derleniyorlar:
  - `PinlyLiveActivity/PinlyLiveActivity.swift`
  - `PinlyLiveActivity/PinlyLiveActivityLiveActivity.swift`
  - `PinlyLiveActivity/PinlyLiveActivityControl.swift`

  **Silmeden önce zorunlu kontrol** — hiçbir yerden referans verilmediğini doğrula:
  ```bash
  grep -rn "PinlyLiveActivityLiveActivity\|PinlyLiveActivityControl" \
    Pinly PinlyLiveActivity --include="*.swift" \
    | grep -v "PinlyLiveActivityLiveActivity.swift\|PinlyLiveActivityControl.swift"
  ```
  Çıktı boşsa sil: `git rm PinlyLiveActivity/PinlyLiveActivity.swift PinlyLiveActivity/PinlyLiveActivityLiveActivity.swift PinlyLiveActivity/PinlyLiveActivityControl.swift`
  Çıktı boş DEĞİLSE referansı incele ve önce onu çöz.
- [x] **1.4 Tek kalan `print(` çağrısını bul ve kaldır** (locationManager.swift:99'daki
  konum hatası logu). Sessiz geçmek yerine `lastError`'a benzer bir yol yoksa sadece
  yorum bırak; `print` release build'de kalmamalı.

**Doğrulama:** Kural 3 build komutu → `BUILD SUCCEEDED`.
**Commit:** `chore: şablon artıkları, eski xcodeproj ve pycache temizlendi`

---

## FAZ 2 — İsimlendirme Geçişi: NotionGO → Pinly (≈1 saat, risk: orta)

**Amaç:** Proje her seviyede tek isim taşısın: Pinly. Klasörler iOS konvansiyonunda olsun.

> ⚠️ **Kritik bilgi:** Proje `PBXFileSystemSynchronizedRootGroup` kullanıyor — yani
> `Pinly/` altındaki dosya/klasör yeniden adlandırmaları pbxproj'a OTOMATİK yansır,
> elle ekleme gerekmez. **TEK İSTİSNA:** `Pinly.xcodeproj/project.pbxproj` içindeki
> exception set'ler dosya yolunu açık yazar. Şu satır var (yaklaşık satır 65):
> ```
> membershipExceptions = (
>     model/PinlyActivityAttributes.swift,
> );
> ```
> `model/` klasörünü yeniden adlandırınca bu yol kırılır → Live Activity extension
> derlenemez. Adım 2.2'de bu satır elle güncellenecek.

- [x] **2.1 Dosya adı düzeltmeleri** (git mv büyük/küçük harf için iki aşamalı olmalı,
  macOS dosya sistemi case-insensitive):
  ```bash
  git mv Pinly/manager/locationManager.swift Pinly/manager/LocationManager_tmp.swift
  git mv Pinly/manager/LocationManager_tmp.swift Pinly/manager/LocationManager.swift
  git mv Pinly/view/home/MoreTab.swift Pinly/view/home/ProfileTab.swift
  ```
  Sonra `ProfileTab.swift` içinde tip adını değiştir: `struct MoreTab` → `struct ProfileTab`.
  Referansı güncelle — tek kullanım yeri `Pinly/ContentView.swift:232`'deki `MoreTab()`
  çağrısı: `ProfileTab()` yap. Kontrol: `grep -rn "MoreTab" Pinly --include="*.swift"` → boş olmalı.
- [x] **2.2 Klasörleri konvansiyona getir:** ⚠️ Uygulama notu: bu Mac'te proje `/System/Volumes/Data`
  (case-INSENSITIVE APFS) üzerinde ve repo'da `core.ignorecase=true` — case-only rename'ler
  (`design→Design` vb.) `git mv` ile TEK adımda başarısız olur ("Invalid argument"). Çözüm
  `locationManager.swift` adımındaki gibi ara-isim üzerinden iki adımlı `git mv` (`git mv X X_tmp`
  sonra `git mv X_tmp Y`). Plain shell `mv` kullanmayın — git index'i case-only fark için
  güncellemiyor, sonraki `git status` klasörü hâlâ eski adıyla "değişti" gösterir ve içerik
  kaybı riski doğurur (bu oturumda yaşandı, `git checkout --` ile kurtarıldı). Ayrıca Xcode
  açıkken senkron klasör rename'i pbxproj'u canlı yeniden yazabilir — rename'den önce Xcode'u
  kapatın.
  ```bash
  git mv Pinly/manager  Pinly/Managers
  git mv Pinly/model    Pinly/Models
  git mv Pinly/services Pinly/Services
  git mv Pinly/design   Pinly/Design
  git mv Pinly/view     Pinly/Views
  git mv Pinly/images   Pinly/Images
  ```
  **Hemen ardından** `Pinly.xcodeproj/project.pbxproj` içinde şu tek satırı düzelt
  (Edit tool ile, başka hiçbir şeye dokunmadan):
  `model/PinlyActivityAttributes.swift,` → `Models/PinlyActivityAttributes.swift,`
  Sonra build al (Kural 3). Extension target'ı da derlendiğinden emin olmak için
  `xcodebuild build ... -target` değil scheme build'i yeterli (extension app'e gömülü).
- [x] **2.3 HomeView'i kendi dosyasına taşı.** `Pinly/ContentView.swift` şu an iki büyük
  view içeriyor. 195. satırdan itibaren (`// MARK: - Tab Bar Ana Yapısı` + `struct HomeView`)
  sonuna kadar kes, yeni dosya `Pinly/Views/home/HomeView.swift`'e taşı
  (import'lar: `SwiftUI`). ContentView.swift'te sadece ContentView kalsın.
- [x] **2.4 "farad" temasını yeniden adlandır.** `ThemeStyle.farad` kişisel kod adı;
  yayınlanacak koda uygun değil. Yeni ad: **`lavender`** (tema zaten "temiz lavanta-beyaz").
  - `Pinly/Design/ThemeManager.swift`: `case farad = "farad"` → `case lavender = "lavender"`
  - `Pinly/Design/Theme.swift`: tüm `ThemeManager.shared.themeKey == "farad"`
    karşılaştırmalarını `ThemeManager.shared.style == .lavender` yap
    (grep: `grep -n "farad" Pinly/Design/Theme.swift` → hepsini değiştir, yorumlar dahil).
  - **UserDefaults migrasyonu zorunlu** — mevcut kullanıcıda `pinly.theme = "farad"`
    kayıtlı olabilir. `ThemeManager.init`'e (Faz 4.3'te zaten elden geçecek, şimdilik
    themeKey getter'ına) şunu ekle:
    ```swift
    // Eski "farad" değerinden migrasyon
    if UserDefaults.standard.string(forKey: ThemeManager.key) == "farad" {
        UserDefaults.standard.set(ThemeStyle.lavender.rawValue, forKey: ThemeManager.key)
    }
    ```
  - Tema seçim UI'sında ("farad" seçeneğini gösteren yer — `grep -rn "farad\|lavender" Pinly/Views`)
    görünen etiketi de güncelle ve 5 dile lokalize et.
- [ ] **2.5 Kök klasör + GitHub repo adı.** ⏸️ **KULLANICI TERCİHİYLE PLAN SONUNA ERTELENDİ**
  (2026-07-13) — `gh` CLI kurulu değil, klasör rename'i çalışma dizinini etkiliyor. Faz 3-6
  şu an `/Users/ferhatakkopru/Desktop/Projects/NotionGO` yolunda tamamlanacak (fonksiyonel
  fark yok), bu adım en son tek seferde yapılacak. Bu adım terminal + kullanıcı işbirliği ister:
  1. Kullanıcıya söyle: **Xcode'u tamamen kapat.**
  2. ```bash
     cd /Users/ferhatakkopru/Desktop/Projects
     mv NotionGO Pinly
     ```
  3. GitHub repo adını değiştir (remote: `FerhatAkkopru/NotionGo`):
     ```bash
     cd Pinly && gh repo rename Pinly --yes
     ```
     `gh` yoksa veya auth yoksa: kullanıcıya GitHub → Settings → Rename yolunu söyle,
     sonra `git remote set-url origin git@github.com:FerhatAkkopru/Pinly.git`
  4. Kullanıcıya söyle: bundan sonra Claude Code oturumlarını
     `/Users/ferhatakkopru/Desktop/Projects/Pinly` içinden başlatsın
     (proje hafızası yol bazlı olduğu için ilk oturumda bağlam yeniden oturur; CLAUDE.md
     repoda olduğundan bilgi kaybı olmaz).
- [x] **2.6 CLAUDE.md'yi gerçekle eşitle.** Şu düzeltmeler yapılacak (bu fazın parçası):
  - Klasör yolları: `Pinly/manager/` → `Pinly/Managers/` (tüm tablo başlıkları), vb.
  - `locationManager.swift (dosya adı küçük harf!)` notunu kaldır → `LocationManager.swift`
  - 4. sekme: "Daha Fazla (ellipsis) — MoreTab" → "Profil (person.crop.circle) — ProfileTab"
  - Yeni gerçekleri ekle: `ProfileSetupView` (onboarding sonrası ad/soyad/doğum yılı),
    `UserProfile` modeli (UserDefaults + Documents/profile_photo.jpg),
    `ThemeManager` + iki tema (slate/lavender) + `pinly.appearance` (light/dark/system),
    ViewModel katmanı (AddPlace/EditPlace/Map/PlanRoute/RouteSummary/QuickAdd/QRScanner/
    SavedRoutes/MainTab/MapPinPicker/PlaceForm ViewModel'leri),
    yeni servisler (`GeocodingService`, `HealthKitService`, `QRCodeGenerating`,
    SavedRouteRepository/RouteURLCoding/SwarmImporting/RouteExporting/WeeklyStatsComputing/
    NotificationScheduling environment key'leri).
  - "Otomatik test yok" cümlesini Faz 3 bitince "PinlyTests target'ı var, CI'da koşuyor" yap
    (şimdilik "test dosyaları var, target Faz 3'te ekleniyor" yaz).
  - LiveActivity şablon artığı uyarısını kaldır (silindiler).

**Doğrulama:** build yeşil + `grep -rn "farad\|MoreTab" Pinly --include="*.swift"` boş +
uygulama simülatörde açılıyor (Faz sonunda bir kez: `xcrun simctl` ile boot edip smoke test
— `/run` skill'i kullanılabilir).
**Commit:** `refactor: Pinly isim geçişi — klasörler, ProfileTab, lavender tema, CLAUDE.md senkron`

---

## FAZ 3 — Test Target'ı: Testleri Gerçeğe Dönüştür (≈1.5 saat, risk: orta)

**Amaç:** `PinlyTests/` altındaki 6 test + 10 mock dosyası şu an HİÇ derlenmiyor
(pbxproj'da test target'ı yok). Bu faz sonunda `xcodebuild test` yeşil koşacak.

- [x] **3.1 Mevcut test klasörünü kenara al** (Xcode target oluştururken çakışmasın):
  ```bash
  mv PinlyTests PinlyTests_backup
  ```
- [x] **3.2 🖱 Xcode'da test target'ı oluştur** (kullanıcıdan iste, birebir tarif):
  1. Xcode'da `Pinly.xcodeproj` aç → menü **File → New → Target…**
  2. iOS sekmesi → **Unit Testing Bundle** → Next
  3. Product Name: **PinlyTests** · Team: (boş/kişisel) · **Testing System: XCTest**
     (Swift Testing DEĞİL — mevcut testler XCTest yazılmış) · Target to be Tested: **Pinly**
  4. Finish. Xcode `PinlyTests/` klasörünü şablon dosyayla yeniden oluşturur.
- [x] **3.3 Şablonu at, gerçek testleri geri koy:**
  ```bash
  rm PinlyTests/PinlyTests.swift        # Xcode'un ürettiği şablon
  mv PinlyTests_backup/* PinlyTests/
  rmdir PinlyTests_backup
  ```
  Synchronized folder sayesinde dosyalar target'a otomatik girer.
- [x] **3.4 Testleri derle ve yeşile çek:**
  ```bash
  xcodebuild test -project Pinly.xcodeproj -scheme Pinly \
    -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40
  ```
  Bu testler hiç derlenmediği için compile hatası ÇIKMASI BEKLENİR (API kaymış olabilir).
  **Kural: testleri uygulamanın bugünkü API'sine uydur; uygulama kodunu değiştirme.**
  İstisna: test gerçek bir bug yakalarsa (davranış hatası), uygulamayı düzelt ve commit
  mesajında belirt. Ayrıca Faz 2'deki isim değişiklikleri (ProfileTab, lavender) testlere
  yansımalı.
- [x] **3.5 🖱 Scheme'i paylaş (CI için şart):** Xcode → Product → Scheme → Manage Schemes →
  `Pinly` satırında **Shared** kutusunu işaretle. Bu,
  `Pinly.xcodeproj/xcshareddata/xcschemes/Pinly.xcscheme` dosyası üretir — commit'e dahil et.
- [x] **3.6 Eksik kritik testleri yaz** (ROADMAP §2.3 hedefleri; her biri ayrı dosya,
  mevcut test stiline — XCTest, @MainActor, in-memory ModelContainer — uy):
  1. `PlaceImporterTests.swift`: tek mekan URL round-trip (build → parse → aynı alanlar),
     rota URL round-trip (yeni `{places,name,category}` formatı + eski düz array parse),
     bozuk base64 → nil, dosya adı sanitizasyonu (GPX/PDF, bug B9 regresyonu).
  2. `LocalEntitlementServiceTests.swift`: `UserDefaults(suiteName: #file)` ile izole
     defaults kullan (teardown'da `removePersistentDomain`). Senaryolar: free kullanıcı
     19→20. mekan sınırı, `notiongo.isPro` → `pinly.isPro` migrasyonu, Pro'da limit yok.
  3. `DefaultBadgeServiceTests.swift`: `check(placeStore:)` — 0/1/5 mekan eşikleri,
     `recordAppOpen` gün serisi (bugün+dün → seri artar, gün atlanınca sıfırlanır).
     UserDefaults injetable değilse önce servise `init(defaults:)` ekle (mevcut
     `LocalEntitlementService` deseniyle aynı — bu uygulama kodu değişikliği serbesttir).
  4. `RouteManagerAlignmentTests.swift` (@MainActor): `setRoute(places:)` sonrası
     `routePlaces.count == places.count` ve sıra korunuyor; `reset()` sonrası her şey boş;
     `resumeNavigation()` son duraktaysa `isRouteComplete == true`.
- [x] **3.7 Tam test koşusu** (Kural 4) → tümü yeşil.

**Doğrulama:** `xcodebuild test` çıktısında `** TEST SUCCEEDED **` ve 6+4 dosyanın tüm
testleri listede görünüyor (0 test koşan "boş" başarıya kanma — çıktıda `Executed N tests`
satırında N ≥ 20 olmalı).
**Commit:** `test: PinlyTests target'ı eklendi, mevcut testler yeşile çekildi, 4 kritik test paketi yazıldı`

---

## FAZ 4 — Bug Düzeltmeleri (≈1 saat, risk: düşük-orta)

**Amaç:** İncelemede bulunan gerçek hataları, artık test güvencesi varken düzeltmek.

- [x] **4.1 Rotadan sapma algılama bug'ı (öncelikli).**
  `Pinly/Managers/RouteManager.swift` → `minimumDistanceToPolyline` sadece polyline'ın
  KÖŞE noktalarına uzaklık ölçüyor; iki nokta arasındaki çizgi parçasını yok sayıyor.
  Uzun düz segmentte rotanın tam üstündeki kullanıcı "75 m saptı" sanılıp gereksiz
  yeniden hesaplama tetikleniyor. Fonksiyonu şununla DEĞİŞTİR (nokta→doğru parçası mesafesi):
  ```swift
  private func minimumDistanceToPolyline(_ polyline: MKPolyline, from coordinate: CLLocationCoordinate2D) -> Double {
      let user = MKMapPoint(coordinate)
      let points = polyline.points()
      let count = polyline.pointCount
      guard count > 0 else { return .infinity }
      guard count > 1 else { return user.distance(to: points[0]) }

      var minDist = Double.infinity
      for i in 0..<(count - 1) {
          minDist = min(minDist, distance(from: user, toSegment: points[i], points[i + 1]))
      }
      return minDist
  }

  /// p noktasının [a,b] doğru parçasına dik izdüşüm mesafesi (metre).
  private func distance(from p: MKMapPoint, toSegment a: MKMapPoint, _ b: MKMapPoint) -> Double {
      let dx = b.x - a.x, dy = b.y - a.y
      let lengthSquared = dx * dx + dy * dy
      guard lengthSquared > 0 else { return p.distance(to: a) }
      let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
      let projection = MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
      return p.distance(to: projection)
  }
  ```
  **Önce testi yaz** (`RouteManagerDeviationTests.swift`): iki noktalı düz bir polyline
  (örn. boylamda 0.005° aralıklı ≈ 400 m) kur, orta noktadan 10 m yanda bir koordinatla
  fonksiyonu çağır → sonuç < 30 m olmalı (eski kodda ~200 m çıkardı). Fonksiyon `private`
  olduğu için testte `@testable` ile erişilemiyorsa erişimi `internal` yap (yorumla belirt).
- [x] **4.2 Türkçe lokalizasyonda 9 eksik anahtar.** ProfileSetupView metinleri
  `tr.lproj/Localizable.strings`'te yok (anahtar Türkçe olduğu için şans eseri doğru
  görünüyor ama açık teknik borç). Eksikler tam olarak şunlar — `en.lproj`'daki sırayla
  `tr.lproj`'a ekle (anahtar = değer):
  `"AD"`, `"Adın"`, `"DOĞUM YILI"`, `"Lütfen tüm alanları doldurun."`,
  `"Pinly'ye Hoş Geldin"`, `"SOYAD"`, `"Sana özel bir deneyim için kendini tanıt."`,
  `"Soyadın"`, `"Örn: 1995"`.
  Doğrulama: bu belgedeki komutla anahtar diff'i tekrar al, boş çıksın:
  ```bash
  for f in en tr es de ru; do grep -o '^"[^"]*"' Pinly/$f.lproj/Localizable.strings | sort -u > /tmp/k_$f; done
  for f in tr es de ru; do echo "--- en vs $f:"; comm -3 /tmp/k_en /tmp/k_$f; done
  ```
- [x] **4.3 ThemeManager'ı düzelt.** İki sorun: (a) `objectWillChange.send()` değer
  yazıldıktan SONRA çağrılıyor (SwiftUI "will change" bekler), (b) singleton'ın
  `@StateObject`'e sarılması sahiplik semantiğini bozuyor. Yeni hali:
  ```swift
  final class ThemeManager: ObservableObject {
      static let shared = ThemeManager()
      static let key = "pinly.theme"

      @Published var themeKey: String {
          didSet { UserDefaults.standard.set(themeKey, forKey: Self.key) }
      }

      private init() {
          var stored = UserDefaults.standard.string(forKey: Self.key) ?? ThemeStyle.slate.rawValue
          if stored == "farad" { stored = ThemeStyle.lavender.rawValue }   // eski değer migrasyonu
          themeKey = stored
      }

      var style: ThemeStyle { ThemeStyle(rawValue: themeKey) ?? .slate }
  }
  ```
  Bağlama değişiklikleri: `PinlyApp`'te `.environmentObject(ThemeManager.shared)` ekle;
  `ContentView`'daki `@StateObject private var themeManager = ThemeManager.shared` satırını
  `@EnvironmentObject var themeManager: ThemeManager` yap. `.id(themeManager.themeKey)`
  mekanizması aynen kalır (tema değişince kökü yeniden kurmak bilinçli tasarım).
  Tema seçimini yazan view'ı bul (`grep -rn "themeKey =" Pinly/Views`) ve hâlâ çalıştığını
  simülatörde tema değiştirerek doğrula.
- [x] **4.4 `AdManager` yarış koşulu küçük düzeltme:** `showInterstitialIfNeeded` içinde
  `interstitial = nil` + `loadInterstitial()` present'ten ÖNCE çağrılıyor; present başarısız
  olursa (`didFailToPresent`) zaten `loadInterstitial()` tekrar çağrılıyor → çifte istek.
  `loadInterstitial()` çağrısını `adDidDismissFullScreenContent`'e taşı; `didFail`'dekini bırak.

**Doğrulama:** `xcodebuild test` yeşil (yeni sapma testi dahil) + simülatörde tema
değiştirme smoke testi.
**Commit:** `fix: sapma algılamada segment mesafesi, TR lokalizasyon eksikleri, ThemeManager yayın düzeni, AdManager çifte yükleme`

---

## FAZ 5 — Mimari Refactorlar (≈3-4 saat, risk: orta-yüksek — testler kalkan)

**Amaç:** Kod artık davranışı bozmadan sadeleştirilebilir; testler Faz 3'te kuruldu.
**Her görev ayrı commit. Her commit öncesi tam test koşusu.**

- [x] **5.1 `RouteManager.setRoute` sentetik key hack'ini kaldır.**
  Bugün `selectedCategories` alanı iki anlam taşıyor: kategori akışında gerçek kategori
  adları, `setRoute`'ta `"0_<uuid>"` uydurma anahtarlar. `routePlaces` ise computed.
  Hedef durum: `routePlaces` GERÇEK kaynak olsun.
  1. `RouteManager`'da `var routePlaces: [Place]` computed'ı sil, yerine
     `@Published private(set) var routePlaces: [Place] = []` ekle.
  2. `setRoute(places:name:)` sadeleşir:
     ```swift
     func setRoute(places: [Place], name: String = "") {
         reset()
         routePlaces = places
         routeName = name
     }
     ```
     (sentetik key döngüsü tamamen silinir).
  3. Kategori akışı için yeni metod:
     ```swift
     /// Kategori seçim akışı bitince çağrılır — seçimleri sıralı rota listesine mühürler.
     func commitCategorySelection() {
         routePlaces = selectedCategories.compactMap { selectedPlaces[$0] }
     }
     ```
     Akışın RouteSummaryView'e geçtiği yeri bul
     (`grep -rn "RouteSummaryView" Pinly/Views/PlacePickerStepView.swift Pinly/Views/CategoryPickerView.swift Pinly/Views/CategoryOrderingView.swift`)
     ve geçişten hemen önce `routeManager.commitCategorySelection()` çağır.
  4. `reset()`'e `routePlaces = []` ekle.
  5. Tüm `selectedCategories`/`selectedPlaces` okuyucularını gözden geçir:
     `grep -rn "selectedCategories\|selectedPlaces" Pinly --include="*.swift"`
     Kural: bu iki alan ARTIK YALNIZCA kategori seçim akışının (picker ekranları) geçici
     state'idir; navigasyon/özet/harita kodu yalnızca `routePlaces` okur.
  6. `RouteManagerAlignmentTests`'i güncelle + yeni test: `commitCategorySelection`
     sıralamayı `selectedCategories` sırasına göre koruyor.
  **Risk / dikkat:** En riskli görev. Simülatörde İKİ akışı da uçtan uca dene:
  (a) MapView → kategori seç → rota → navigasyon başlat, (b) kayıtlı rotayı başlat.
  `\.dismissRouteFlow` davranışının (bug B5) bozulmadığını X butonuyla doğrula.
- [x] **5.2 Live Activity'yi RouteManager'dan ayır.** `RouteLiveActivityPresenting`
  protokolü zaten var; implementasyonu ayrı sınıfa taşı:
  1. Yeni dosya `Pinly/Managers/RouteLiveActivityController.swift`:
     `@MainActor final class RouteLiveActivityController: RouteLiveActivityPresenting`.
     RouteManager'daki `liveActivity` property'si + `startLiveActivity/updateLiveActivity/
     endLiveActivity` gövdeleri buraya taşınır. İhtiyaç duyduğu veriler (instruction,
     remainingDistance, waypoint index, routePlaces adları, completionPercentage) için
     küçük bir değer tipi tanımla: `struct LiveActivitySnapshot` — RouteManager her
     güncellemede bunu üretip controller'a verir.
  2. RouteManager `private let liveActivityController = RouteLiveActivityController()`
     tutar; eski metod adları RouteManager'da ince birer forwarding olarak kalır
     (`func startLiveActivity() { liveActivityController.start(snapshot: makeSnapshot()) }`)
     → hiçbir view değişmez.
  3. RouteManager artık `RouteLiveActivityPresenting`'e conform olmaz; protokolü
     controller taşır. `grep -rn "RouteLiveActivityPresenting" Pinly` ile başka conform
     bekleyen yer olmadığını doğrula.
- [x] **5.3 UserProfile'ı servis katmanına hizala.** `UserProfile` struct'ı veri modeli
  olarak kalır ama UserDefaults/dosya IO'su servise taşınır:
  1. Yeni dosya `Pinly/Services/ProfileService.swift`:
     ```swift
     protocol ProfileProviding: AnyObject {
         var profile: UserProfile? { get }
         func save(_ profile: UserProfile)
         func loadPhoto() -> UIImage?
         func savePhoto(_ image: UIImage)
         func deletePhoto()
     }
     final class DefaultProfileService: ProfileProviding, ObservableObject { static let shared = ... }
     ```
     Gövdeler UserProfile'daki static metodlardan taşınır (davranış birebir aynı:
     `pinly.userProfile` anahtarı, `Documents/profile_photo.jpg`, 800px küçültme, 0.85 JPEG).
  2. `ServiceEnvironment.swift`'e `\.profile` key'i ekle (mevcut desenle birebir),
     `PinlyApp`'e `.environment(\.profile, DefaultProfileService.shared)` ekle.
  3. Çağrı yerlerini bul ve geçir: `grep -rn "UserProfile\.\(load\|save\|loadPhoto\|savePhoto\|deletePhoto\)" Pinly --include="*.swift"`
     (beklenen: ProfileSetupView, ProfileView, MainTab selamlaması). Hepsi environment'tan alır.
  4. UserProfile'daki static metodları sil; struct yalnızca alanlar + `age/fullName/initials` kalır.
- [x] **5.4 Kategori verisini kanonikleştir (tek seferlik migrasyon).** DB'de eski Türkçe
  kategori string'leri var ("restoran", "müze"...); her okuma `PlaceCategory.from(_:)`
  ile tolere ediliyor. Kalıcı düzeltme: `PlaceStore.load(context:)` sonuna bir defalık
  normalizasyon ekle:
  ```swift
  // Eski TR kategori string'lerini kanonik rawValue'ya çevir (tek seferlik, idempotent)
  var didMigrate = false
  for place in places where PlaceCategory(rawValue: place.category) == nil {
      place.category = PlaceCategory.from(place.category).rawValue
      didMigrate = true
  }
  if didMigrate { save(context: context) }
  ```
  `PlaceCategory.from(_:)` SİLİNMEZ (deep link/QR/Swarm importları hâlâ serbest metin
  getirebilir) — CLAUDE.md'deki "daima from kullan" kuralı da kalır.
- [x] **5.5 Bilinçli olarak YAPILMAYACAKLAR** (yürütücü bunlara girişmesin):
  - ViewModel'lerdeki `init(x: X = Default.shared)` deseni environment-DI'a çevrilMEYECEK.
    İki mekanizma (view→environment, VM→ctor default) kabul edilmiş pragmatik denge;
    testler mock enjekte edebiliyor, yeterli. Büyük churn, sıfır kullanıcı değeri.
  - `LocationManager`'a `@MainActor` eklenmeyecek (delegate isolation zinciri riskli,
    mevcut kod main thread'de zaten güvenli çalışıyor).
  - SwiftData şema değişikliği yapılmayacak (`SavedPlaceSnapshot.placeId` bu planın
    DIŞINDA — ayrı, dikkatli bir migrasyon planı ister; CLAUDE.md'de kayıtlı kalsın).
- [x] **5.6 CLAUDE.md mimari bölümünü bu fazın sonuçlarıyla güncelle**
  (routePlaces artık stored + commitCategorySelection, RouteLiveActivityController,
  ProfileService, kategori normalizasyonu).

**Doğrulama:** tam test + simülatörde uçtan uca akış: onboarding→profil→mekan ekle→
kategori akışıyla rota→navigasyon başlat→Live Activity göründü→durakta duraklat→tamamla.
> ⚠️ **2026-07-14 kullanıcı kararı:** Tap-driven E2E (Accessibility izni gerektiriyor —
> bu oturumda verilmedi) BİLİNÇLİ OLARAK ATLANDI, kullanıcı riski kabul etti. Yerine
> geçen doğrulama: 67 unit test (routePlaces/commitCategorySelection/deviation dahil
> özel regresyon testleri) + build yeşil + kısmi simülatör smoke screenshot'ları
> (Faz 2 onboarding render, Faz 4 MainTab render, Faz 5 ProfileTab gerçek veriyle
> render). **Sonraki oturumda gerçek dokunuşlu E2E hâlâ yapılmadı — ilk fırsatta
> (Accessibility izni verilirse) yapılmalı, özellikle routePlaces refactor'ünün
> gerçek cihaz/simülatör navigasyon akışında hiç doğrulanmadığını unutma.**
**Commit'ler:** `refactor: routePlaces tek kaynak, sentetik key kaldırıldı` ·
`refactor: Live Activity RouteLiveActivityController'a ayrıldı` ·
`refactor: ProfileService — UserProfile IO'su servis katmanına` ·
`chore: eski kategori string'leri kanonikleştirildi + CLAUDE.md senkron`

---

## FAZ 6 — CI + Süreklilik (≈30 dk, risk: yok)

**Amaç:** Yeşil testler bir daha asla sessizce bozulmasın.

- [ ] **6.1 GitHub Actions workflow'u:** `.github/workflows/ci.yml`:
  ```yaml
  name: CI
  on:
    push:
      branches: [main]
    pull_request:

  jobs:
    test:
      runs-on: macos-15
      steps:
        - uses: actions/checkout@v4
        - name: Xcode sürümünü seç
          run: sudo xcode-select -s /Applications/Xcode_16.2.app || sudo xcode-select -s /Applications/Xcode.app
        - name: Simülatör listesi (teşhis için)
          run: xcrun simctl list devices available | grep iPhone | head -5
        - name: Test
          run: |
            xcodebuild test -project Pinly.xcodeproj -scheme Pinly \
              -destination 'platform=iOS Simulator,name=iPhone 16' \
              CODE_SIGNING_ALLOWED=NO
  ```
  Not: Faz 3.5'teki paylaşılan scheme olmadan CI koşamaz — commit'lendiğini doğrula:
  `ls Pinly.xcodeproj/xcshareddata/xcschemes/`. İlk push'ta işlem başarısız olursa
  runner'daki simülatör adına bak (teşhis adımı bunun için) ve destination'ı uyarla.
- [ ] **6.2 Commit disiplinini CLAUDE.md'ye yaz** (kullanıcının "hi", "." geçmişine son):
  CLAUDE.md'ye kısa bölüm ekle:
  > **Commit kuralı:** `tip: açıklama` formatı (`feat:`, `fix:`, `refactor:`, `chore:`,
  > `test:`, `docs:`). Tek satır, Türkçe, ne yapıldığını söyler. "hi", "." gibi mesaj yasak.
- [ ] **6.3 `MASTER_PLAN.md`'nin durumunu kapat:** tüm kutular işaretliyse dosyanın en
  üstüne `> ✅ TAMAMLANDI — <tarih>` satırı ekle; plan tarihçe olarak repoda kalır.
- [ ] **6.4 `main`'e merge:** kullanıcıya özet göster, onay al:
  ```bash
  git checkout main && git merge tidy/master-plan && git push origin main
  ```

**Doğrulama:** GitHub Actions'ta ilk koşu yeşil (push sonrası `gh run watch` ile izlenebilir).
**Commit:** `ci: GitHub Actions test pipeline + commit konvansiyonu`

---

## FAZ 7 — Yayın Hazırlığı (⛔ APPLE DEVELOPER HESABI GEREKTİRİR — hesap gelince)

**Amaç:** Paranın ve reklamın gerçeğe bağlanması. Bu faz hesap olmadan BAŞLATILMAZ;
plan burada hazır dursun.

- [ ] **7.1 RevenueCat'i gerçekten bağla.** Paket SPM'de zaten var (5.67.0) ama
  **hiçbir target'a linkli değil ve kodda import yok** — yarım bırakılmış.
  1. 🖱 Xcode: Pinly target → General → Frameworks, Libraries → `+` → **RevenueCat** ekle.
  2. App Store Connect'te ürünler: `pinly_pro_monthly` ($4.99), `pinly_pro_yearly` ($39.99);
     RevenueCat panelinde "pro" entitlement + "default" offering'e bağla.
  3. `PinlyApp.init()`'e (MobileAds.start'tan önce):
     ```swift
     Purchases.logLevel = .warn
     Purchases.configure(withAPIKey: "<revenuecat_public_sdk_key>")
     ```
  4. Yeni dosya `Pinly/Services/RevenueCatEntitlementService.swift` —
     `EntitlementProviding`'e conform; `isPro` getter'ı
     `Purchases.shared.cachedCustomerInfo?.entitlements["pro"]?.isActive == true` okur,
     `customerInfoStream`'i dinleyip `objectWillChange` yayar. Protokoldeki `isPro` setter'ı
     RevenueCat dünyasında anlamsız → protokolü `var isPro: Bool { get }` yap ve
     PaywallView'daki placeholder `isPro = true` satırlarını kaldır (zaten purchase akışı geliyor).
     `LocalEntitlementService` DEBUG/simülatör fallback'i olarak kalır.
  5. `PinlyApp`'te `.environment(\.entitlements, ...)` satırını RevenueCat servisine çevir —
     **mimari sayesinde başka hiçbir dosya değişmez** (7 gate noktası protokolden okuyor).
  6. `PaywallView.swift:85` ve `:94` TODO'ları:
     `Purchases.shared.purchase(package:)` / `Purchases.shared.restorePurchases()` +
     yükleniyor durumu + hata alert'i. Fiyatları hardcode etmek yerine offering'den çek.
- [ ] **7.2 AdMob'u yayına hazırla.**
  1. Gerçek ID'ler: `Pinly/Info.plist` → `GADApplicationIdentifier` (şu an test:
     `ca-app-pub-3940256099942544~1458002511`) ve `AdManager.interstitialAdUnitID`
     (şu an test: `.../4411468910`).
  2. **UMP consent akışı (eksik — Avrupa'da zorunlu):** Yeni dosya
     `Pinly/Services/ConsentService.swift`; uygulama açılışında (ContentView.onAppear,
     onboarding sonrası):
     ```swift
     import UserMessagingPlatform

     ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { error in
         guard error == nil else { return }
         ConsentForm.loadAndPresentIfRequired(from: rootViewController) { _ in
             if ConsentInformation.shared.canRequestAds { MobileAds.shared.start { _ in } }
         }
     }
     ```
     ve `PinlyApp.init`'teki koşulsuz `MobileAds.shared.start`'ı bu akışın arkasına al.
  3. **ATT izni:** `Info.plist`'e `NSUserTrackingUsageDescription` (5 dilde
     InfoPlist.strings ile) + UMP formu kapandıktan sonra
     `ATTrackingManager.requestTrackingAuthorization`.
- [ ] **7.3 Crash/analytics:** Firebase Crashlytics veya Sentry SPM ile; sadece kurulum +
  dSYM upload script'i. (Seçimi kullanıcıya sor — AskUserQuestion.)
- [ ] **7.4 TestFlight kontrol listesi:** gerçek cihazda navigasyon + Live Activity testi,
  konum izin metinlerinin 5 dilde Info.plist karşılıkları, App Privacy formu (konum,
  sağlık, reklam kimliği), ekran görüntüleri, `pinly://` scheme'inin App Store incelemesi
  için demo notu.

**Doğrulama:** Sandbox hesabıyla satın alma + restore; test cihazında UMP formu (EEA
simülasyonu: `ConsentDebugSettings` ile) ; reklamın Pro'da gösterilmediği.

---

## BİTİŞ KRİTERLERİ — "Proje tatlı oldu" tanımı

- [ ] Repo/klasör/proje her yerde **Pinly**; `NotionGO` kelimesi yalnızca migrasyon
      kodlarında (`notiongo.isPro` anahtarı) geçiyor
- [ ] `xcodebuild test` yeşil, CI her push'ta koşuyor, 30+ test var
- [ ] Ölü dosya yok, tüm dosya adları içindeki tiple aynı, klasörler PascalCase
- [ ] Sapma algılama segment-doğru; navigasyon iki akıştan da uçtan uca çalışıyor
- [ ] CLAUDE.md ile kod %100 aynı gerçeği anlatıyor
- [ ] (Faz 7 sonrası) Ödeme gerçek, reklam consent'li, test ID'si kalmadı

## Bilinçli ertelenenler (bu planın dışında, unutulmasın)
- `SavedPlaceSnapshot.placeId` migrasyonu (isimle eşleşme kırılganlığı)
- Toplu mekan silme, Haritada Keşfet modu, hazır İstanbul rota paketleri (ROADMAP)
- Supabase / iCloud / Watch (Faz 3 ürün planı)
