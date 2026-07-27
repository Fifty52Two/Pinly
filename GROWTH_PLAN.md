# GROWTH_PLAN.md — Pinly Büyüme & Lansman Ana Planı (2026-07-23)

> **Bu dosya nedir:** RELEASE_PLAN.md'nin (TestFlight'a çıkış — FAZ 6.3 tamamlandı, beta ONAYLANDI)
> devamı. Ürünü "yayında olan app"ten "kullanıcı çeken ve kazanç üreten app"e taşıyan uçtan uca plan.
> İlerleme `[x]`/`[ ]` kutucuklarıyla takip edilir. Her fazda **Claude görevleri** ve **Ferhat görevleri**
> ayrı listelenir. Tüm kod işleri **MVVM + protokol tabanlı servis katmanı (SOLID, özellikle DIP)**
> kurallarına uyar: yeni her yetenek önce protokol, sonra somut servis, ViewModel'lere enjeksiyon.
> Büyük tasarım/UX kararları uygulanmadan önce AskUserQuestion ile onaylanır.

## Konumlandırma (her kararın pusulası)

**"Kaydettiğin yerleri yaşanmış günlere çeviren uygulama."**
Rakip Google Maps'in "kaydedilenler"i — Google kaydettirir ama *yürünebilir bir güne çevirmez*,
*anıya dönüştürmez*. TikTok/IG keşfettirir ama *plana çevirmez*. Pinly bu iki kopukluğu birleştirir:
keşfet → kaydet → rotala → yürü → anılaştır → paylaş (→ paylaşım yeni kullanıcı getirir).

---

## Model İşbölümü (2026-07-23 kararı: Fable sadece Fable gerektiren işlerde)

**Çalışma düzeni:** Fable spec yazar → Sonnet uygular → Fable diff'i denetler (`/code-review`).
Sonnet oturumu: `claude --model sonnet` (veya oturum içinde `/model`). Sonnet oturumu önce
CLAUDE.md + ilgili spec dosyasını okur.

**SPEC'LER HAZIR (Fable, 2026-07-23) — Sonnet bunlardan çalışır:**
- `specs/FAZ2_BUG_TURU_SPEC.md` — **İLK İŞ BU** (yarıçap fix algoritması + segment invariant + placeId)
- `specs/FAZ1_REVENUECAT_KARAR.md` — karar katmanı + görev listesi (Ferhat OAuth/.p8 sonrası)
- `specs/FAZ3_ANI_GUNLUGU_SPEC.md` — migration tasarımı + RouteMemoryStoring/MemoryCardComposing
- `specs/FAZ5_SUPABASE_MIMARI.md` — şema/RLS/moderasyon (Fable onayı olmadan şema DEĞİŞMEZ)
- `specs/FAZ6_UI_YON.md` — wow koreografileri + Liquid Glass stratejisi + Sonnet'lik animasyonlar
- `content/routes/tr/istanbul.json` — pilot katalog: 8 rota × 5 dil (5'i `verified:false` —
  FAZ 4 doğrulama scriptinden geçmeden yayınlanamaz; katalog formatı `pinly-route-catalog-v1`)
- `marketing/ASO_METIN_SETI.md` — 5 dil mağaza metinleri + Search Ads kelime seti + SS planı

**🧠 FABLE işleri (muhakeme/mimari/incelik gerektirir):**
- SwiftData migration tasarımları (RouteHistory foto referansları, ileride şema evrimi)
- Supabase şeması + RLS/güvenlik + moderasyon mimarisi (FAZ 5 V2'nin tasarım katmanı)
- MapKit/concurrency sınıfı ince buglar (bugünkü polyline orta-nokta / indeks hizası türü işler)
- RevenueCat entegrasyonunun KARAR katmanı (entitlement kenar durumları, beta flag etkileşimi,
  paywall zamanlama stratejisi) — kod iskeleti Sonnet'e devredilebilir
- Rota kataloğu İÇERİK üretimi (dünya bilgisi + halüsinasyon riski yüksek — kalite burada yaşar)
- UI/UX yön kararları, wow animasyonlarının zor olanları (matchedGeometry mimarisi, Liquid Glass
  adaptasyon stratejisi), paywall/onboarding dönüşüm metinleri
- ASO/PR/pazarlama metinleri (5 dil, ton kritik) + fiyat/strateji revizyonları
- Sonnet çıktılarının code review'u + haftalık metrik yorumlama

**⚙️ SONNET işleri (spec verilince net):**
- FAZ 1 RevenueCat kod iskeleti (protokol zaten çizili — somut sınıf + PaywallView bağlama)
- FAZ 2 bug fix'leri (kök nedenler bu dosyada tarif edildi — uygulaması mekanik)
- FAZ 3 UI katmanı (foto satırı, günlük timeline ekranı; kart kompozisyonu spec'ten)
- FAZ 4 StarterRouteService genişletme, JSON katalog plumbing, koordinat doğrulama scripti
- FAZ 5 V1 (lokal profil sayaçları) + V2'nin CRUD/ekran katmanı (şema Fable'dan gelince)
- FAZ 6'nın basit animasyonları (sayaç, spring pop, haptic), lokalizasyon eklemeleri
- Ekran görüntüsü otomasyonu, test yazımı/koşturma, build/TestFlight rutinleri

## ☀️ GÜNCEL DURUM (2026-07-23 gündüz, çoklu-ajan turu sonu)

Ferhat paywall sandbox testini yaparken (satın alma BAŞARILI — "You're all set" ekranı doğrulandı),
3 paralel Sonnet ajanı (izole worktree) FAZ 3 + FAZ 4 + FAZ 5 V1'i uyguladı; hepsi main'e
birleştirildi (2 merge commit, conflict'ler elle çözüldü — hepsi katkı-ekleyici, veri kaybı yok).
**Ana dal: 181/181 test yeşil.** Ayrıca FAZ 1 kuyruğu kapatıldı (trial uygunluk kontrolü) ve
Ankara rota kataloğu eklendi (9/9 durak MKLocalSearch doğrulamalı).

**ÖNEMLİ OPERASYONEL BULGU:** XcodeBuildMCP'nin session default'ları (`projectPath` dahil) eş
zamanlı çalışan ajanlar arasında PAYLAŞILIYOR (süreç-global state, konuşma-izole değil) — bir
ajanın `session_set_defaults` çağrısı diğerinin varsayılanını sessizce değiştirebiliyor. Bunu bir
test sonucunun (162 geçti sanılan) aslında yanlış worktree'de koştuğunu keşfederek bulduk. KURAL:
paralel ajanlar XcodeBuildMCP kullanırken, her build/test çağrısından HEMEN ÖNCE
`session_set_defaults` ile projectPath'i açıkça yeniden sabitle — asla önceki bir çağrının hâlâ
geçerli olduğunu varsayma.

**Kalan (bu turda dokunulmadı):**
- FAZ 6 (UI wow animasyonları) — **wow #1 (rota tamamlama sekansı) + haptic haritası +
  `contentTransition(.numericText())` sonraki turda ayrı bir Sonnet oturumunda tamamlandı**
  (bkz. FAZ 6 bölümü altındaki güncel durum). Wow #2-6 (zoom geçişleri, pin/scroll animasyonları,
  Liquid Glass, boş durumlar) hâlâ ertelendi — spec'teki sıralamaya göre sıradaki tur.
- FAZ 5 V2 (Supabase) — Ferhat'ın hesap açması gerekiyor, kod işi ondan sonra.
- FAZ 7 (pazarlama) — ASO taslağı hazır, ekran görüntüsü/video/PR Ferhat'ın eylemini gerektiriyor.
- Rota kataloğu Dalga 1 devamı (İzmir/Bursa/Antalya/...) — Ankara gibi MKLocalSearch doğrulamalı
  üretilebilir, istenirse devam edilir.

## 🌅 GÜNCEL DURUM (2026-07-23 gece, otonom oturum sonu) — ESKİ, YUKARIDAKİ GÜNCEL

**Kod durumu:** FAZ 1 + FAZ 2 + seigaiha UI + tüm doküman/spec'ler **main'e 4 tematik commit'le
işlendi** (b57722e → d534f40), working tree temiz, **149/149 test yeşil**. PUSH EDİLMEDİ
(SSH anahtarı parola korumalı — Ferhat terminalden `git push` atacak).

**Ferhat sabah listesi (sırayla):**
1. `git push` (4 yeni commit)
2. **Xcode'u TAMAMEN kapat-aç** → Cmd+R → GPX İndir → paywall: $2.99/$29.99 + "7 Gün Ücretsiz"
   rozeti gelmeli (dünkü "mağazaya ulaşılamıyor" iki kök nedeniyle çözüldü; Xcode açıkken scheme
   diskten değiştiği için son deneme eski scheme'le koşmuştu)
3. Satın al → gate'ler açılıyor mu; Debug → StoreKit → Manage Transactions'tan sil → Restore dene
4. Test geçtiyse: Build 4 archive + TestFlight upload (beta notları FAZ2 spec'te) + Public Link'i
   10-20 kişiye dağıt
5. (Bekleyen karar) RevenueCat'te kullanılmayan Lifetime paketi + eski "Pinly route&places Pro"
   entitlement'ı temizlensin mi? "Temizle" de yeter.

**Sonraki geliştirme sırası (takvimle uyumlu):** FAZ 3 Anı Günlüğü (Sonnet oturumu:
`specs/FAZ3_ANI_GUNLUGU_SPEC.md` — spec'e soft-paywall etkileşim uyarısı eklendi) + FAZ 6 wow #1
(tamamlama sayaç animasyonu — aynı ekran bölgesi, FAZ 3'le birlikte tek turda mantıklı) → Build 5.
Lansman öncesi FAZ 1 kuyruğu: trial UYGUNLUK kontrolü (`checkTrialOrIntroDiscountEligibility`) +
ASC review screenshot'ı (gerçek paywall'dan 1170×2532).

## FAZ 1 — Para Altyapısı: RevenueCat (≈1 hafta) — EN ÖNCELİKLİ

Paywall placeholder olduğu sürece App Store'a çıkılamaz; her şey bunun arkasında.

**Ferhat:** ✅ HEPSİ TAMAM (2026-07-23)
- [x] RevenueCat hesabı + proje "Pinly route&places" (`proj5955a1be`)
- [x] `/mcp` → revenuecat OAuth bağlandı
- [x] ASC API anahtarı (.p8, Key ID Q5J9H5X5Y3) + In-App Purchase anahtarı (NDAJBUH44D) üretildi,
      ikisi de RevenueCat'e işlendi (`app_store_connect_api_key_configured` + `subscription_key_configured` = true)
- [x] ASC'de abonelik grubu "Pinly Pro" + `pinly_pro_monthly`, `pinly_pro_yearly` açıldı.
      **GERÇEKLEŞEN fiyat (plandan farklı, Ferhat kararı):** aylık $2,99 / ₺149,99 —
      yıllık $29,99 / ₺1.499,99 (+7 gün ücretsiz deneme)
- [x] Sandbox test hesabı: deneme_pinly@tester.com (Türkiye)

**Claude (mağaza kurulumu ✅ 2026-07-23):**
- [x] RevenueCat: App Store app'i `appc32f960641` (com.farad.pinly), entitlement **`pro`**
      (`entlb8f28bde64`), ürünler RevenueCat'te oluşturulup `pro`ya + `default` offering'in
      `$rc_monthly`/`$rc_annual` paketlerine bağlandı (Test Store ürünleri de `pro`da — sandbox testi için).
      Public SDK key: `appl_RUAmxHPfjrHHoKGQwOmrVllWMiH` (Info.plist `RevenueCatAPIKey`).
- [x] ASC metadata Claude tarafından ASC API ile dolduruldu: 5 dil ürün adı+açıklama, "Pinly Pro"
      grup adı 5 dil, 175 bölge availability, yearly'de 175 bölgede 7 gün FREE_TRIAL intro offer.
      Kalan tek eksik: **review ekran görüntüsü** (gerçek paywall UI'ı çıkınca yüklenecek;
      ürünler o yüzden MISSING_METADATA görünür, ilk IAP zaten yeni app sürümüyle submit edilir).
- [ ] App Store Connect MCP kurulumu OPSİYONEL kaldı — .p8 ile doğrudan ASC API scripti çalışıyor
      (bkz. bu oturum), MCP'ye gerek kalmadı; istenirse sonra kurulur.

**Sonnet (kod ✅ TAMAMLANDI 2026-07-23, aynı oturumda model işbölümü ilk kez fiilen çalıştı):**
- [x] SPM: `RevenueCat` ürünü hem `Pinly` hem `PinlyTests` target'ına linklendi (pbxproj elle
      düzenlendi — paket referansı zaten resolved'du, sadece XCSwiftPackageProductDependency +
      Frameworks build phase eksikti).
- [x] `RevenueCatEntitlementService: EntitlementProviding, ObservableObject` (`EntitlementService.swift`) +
      saf `EntitlementMapper.isPro(customerInfo:)` (`EntitlementMapper.swift`) + 4 birim test
      (`EntitlementMapperTests.swift` — RC'nin gerçek JSON şemasıyla `Decodable` üzerinden kurulan
      `CustomerInfo`; bir entitlement'ın `EntitlementInfos.all`'da görünmesi için `subscriptions`
      altında AYNI `product_identifier`'lı kayıt da ŞART, yoksa RC sessizce düşürüyor — SDK
      kaynağından (checkouts/purchases-ios-spm) doğrulandı).
- [x] `PurchasesProviding` protokolü + `RevenueCatPurchasesService` (`PurchasesService.swift`) —
      offering/purchase/restore PaywallView için ayrı bir servis (entitlement kararından bağımsız).
      `RevenueCatConfig.configureIfNeeded()` idempotent tek nokta.
- [x] `PinlyApp` composition root: `#if DEBUG` → `LocalEntitlementService`, `#else` →
      `RevenueCatEntitlementService` (§1 kararı harfiyen); `purchasesService` ise DEBUG/Release
      FARKETMEKSİZİN her zaman configure edilir — StoreKit Config dosyasıyla DEBUG'da da gerçek
      paywall/satın alma testi mümkün olsun diye. Satın alma sonrası PaywallView `entitlements.isPro`
      set eder: DEBUG'da gerçek toggle, Release'te no-op (zaten `customerInfoStream` mirror'lıyor) —
      iki kararı da (mimari §1 + Kabul Ölçütü'nün DEBUG testi) birlikte sağlıyor.
- [x] `PaywallView` 3 TODO gerçek `purchases.offerings()/purchase()/restorePurchases()`'a bağlandı;
      yıllık paket önseçili + gerçek intro offer'dan "7 Gün Ücretsiz" rozeti, yükleniyor/hata/tekrar-dene
      durumları, dinamik `localizedPriceString` (hardcode fiyat YOK). `source` parametresi eklendi
      (default `"limit_reached"` — mevcut 10 çağrı sitesi DEĞİŞMEDEN aynı kaldı).
- [x] Soft paywall tetikleyicisi: `RouteSummaryView` kutlama-overlay kapanışında (App Store review
      promptuyla aynı ana denk gelmeyecek şekilde, `else` dalında), `pinly.softPaywallShown` ile
      tek seferlik, `source: "first_route_completed"`.
- [x] Analytics: `paywallShown(source:)`, `trialStarted(product:)`, `purchaseCompleted(product:)`,
      `restoreCompleted` eklendi (`AnalyticsEventTests.swift` güncellendi).
- [x] `Pinly.storekit` (repo kökü) — `pinly_pro_monthly`/`pinly_pro_yearly` + yıllıkta 7 gün deneme;
      paylaşılan şemaya hem LaunchAction hem TestAction'a bağlandı.
- [x] **Gerçek derleme + test doğrulaması yapıldı** (XcodeBuildMCP, iPhone 16 simülatör): build
      SUCCEEDED, **143/143 test yeşil** (4 yeni EntitlementMapper testi dahil). RevenueCat SPM paketi
      gerçekten resolve oldu, `CustomerInfo`/`EntitlementInfo` SDK kaynağından okunarak doğru JSON
      şeması bulundu (`request_date`/snake_case + `.convertFromSnakeCase`, expires_date karşılığında
      `subscriptions` eşleşmesi şartı).
- [x] **Fable review kapısı GEÇİLDİ (2026-07-23):** 1 CONFIRMED bug bulunup düzeltildi — soft
      paywall `dismissRouteFlow()` fullScreenCover'ı söktükten SONRA sunulmaya çalışılıyordu
      (sökülen view'dan sheet sunulamaz → hiç görünmezdi) ve tek seferlik `pinly.softPaywallShown`
      bayrağı gösterim garantiye alınmadan yakılıyordu. Düzeltme: karar+bayrak yakma
      `RouteSummaryViewModel.consumeSoftPaywallOffer(defaults:)`'a taşındı (Pro kullanıcıda bayrak
      YAKILMAZ), rota akışı paywall kapanana dek açık kalıyor, reset+dismiss sheet'in onDismiss'inde.
      +1 minor: satın alma başarılı ama entitlement eşleşmesi gelmezse kullanıcı paywall'da kilitli
      kalıyordu ve `purchase_completed` atlanıyordu — event+kapanış artık ödemeye bağlı, eşleşmeye
      değil. +3 regresyon testi → **146/146 yeşil**. Bilinen sınırlama (bilinçli, FAZ 6'ya not):
      "7 Gün Ücretsiz" rozeti ürün metadata'sından geliyor, kullanıcı UYGUNLUĞU kontrol edilmiyor
      (`checkTrialOrIntroDiscountEligibility`) — trial'ını kullanmış kullanıcı yanlış CTA görebilir;
      lansman öncesi eklenecek.
- [x] **"Mağazaya ulaşılamıyor" sorunu KÖKTEN ÇÖZÜLDÜ (2026-07-23 gece):** iki ayrı kök neden vardı —
      (1) Pinly.storekit VAR OLMAYAN "v3.3" formatındaydı (Xcode parse edemiyordu) → RC repo'sundaki
      gerçek Xcode üretimi örneklerden kanonik v4'e yazıldı; (2) scheme'deki
      StoreKitConfigurationFileReference yolu yanlış çözümleniyordu (Xcode yolu
      `Pinly.xcodeproj/project.xcworkspace`'e göre çözüyor; `../../../` yerine `../../Pinly.storekit`).
      Her ikisi de OTOMASYONLA KANITLANDI: `StoreKitConfigFileTests` (SKTestSession, dosya geçerliliği +
      trial) + RC offerings entegrasyon testi (backend offering → `$rc_monthly`/`$rc_annual` →
      gerçek ürün ID eşleşmesi) + scheme-yolu probe testi (geçti, sonra silindi). **149/149 yeşil.**
      ÖĞRENİLEN: xcodebuild, TestAction'daki SK config'i UYGULUYOR; SKTestSession testlerde
      dosyayı test bundle resource'undan okur (dosya PinlyTests target'ına resource eklendi).
- [ ] **Sandbox/StoreKit-Config'te uçtan uca insan testi** (satın al → isPro açık → gate'ler açılıyor →
      restore → iptal davranışı) — Ferhat: **Xcode'u TAMAMEN KAPAT-AÇ** (scheme diskten değişti),
      Cmd+R → GPX İndir → paywall'da $2.99/$29.99 + "7 Gün Ücretsiz" rozeti gelmeli → satın al →
      Debug → StoreKit → Manage Transactions ile restore/iptal senaryoları.
- [ ] Paywall redesign (FAZ 6 UI diliyle): yıllık planı öne çıkar, "7 gün ücretsiz dene" ana CTA —
      bu turda FONKSİYONEL entegrasyon yapıldı (offering/purchase/restore), görsel "wow" katmanı
      (matchedGeometry, Liquid Glass vb.) FAZ 6'ya bırakıldı.
- [ ] `FeatureFlags.unlimitedPlacesInBeta` gözden geçirildi (kod değişmedi): `isTestFlightBuild`
      zaten Release+sandbox receipt'e bakıyor — App Store production build'de otomatik `false` olur,
      ekstra bir "beta bitti" flag'ine gerek yok, gate'ler kendiliğinden aktifleşir.

## FAZ 2 — Bug Turu & Cila (2-3 gün) — KOD TAMAMLANDI 2026-07-23 (Sonnet), review bekliyor

- [x] **Yakınımda yarıçap bug'ı** — Sonnet, `specs/FAZ2_BUG_TURU_SPEC.md`'ye göre uygulandı:
      1. Kök neden A: `GeocodingService.swift` metin arama dalında `radiusMeters * 2` yapıldı (span=çap).
      2. Kök neden B: `NearbyResultBander.diversify` eklendi (3 bant round-robin, >1km'de devrede) —
         `DefaultNearbySearchService.searchNearby` artık `prefix(25)` yerine bunu çağırıyor.
      3. 6 birim test (`NearbyResultBanderTests.swift`) — yoğun küme + uzak bant senaryosu dahil.
         XcodeBuildMCP simülatör GPS doğrulaması HENÜZ YAPILMADI (Fable review'unda yapılabilir).
- [x] Koordinatsız mekan segment kaydırma — `RouteSegmentPlanner` (yeni saf tip) ile
      `RouteManager.calculateRoutes` yeniden yazıldı; `unroutableStopCount` eklendi + RouteSummaryView
      ayrı uyarı satırı + 5 dil lokalizasyon. 6 birim test (`RouteSegmentPlannerTests.swift`).
- [x] `PlanRouteView` placeId fallback — `SnapshotPlaceResolver` (SavedRouteManager.swift) her iki
      call site'ta da kullanılıyor; asıl bulunan açık: `hydrateIfEditing` placeId'li ama silinmiş
      mekanlarda isme HİÇ düşmüyordu — düzeltildi + regresyon testi eklendi.
- [x] Build numarası 4'e yükseltildi (Xcode proje ayarları). Tüm testler yeşil: **134/134**.
- [ ] **TestFlight'a fiili yükleme (archive+upload) BEKLİYOR** — imzalama/Organizer erişimi
      gerektirdiği için Ferhat'ın onayı/aksiyonu gerekiyor (beta notları FAZ2 spec'te hazır).
- [x] **Fable review kapısı GEÇİLDİ (2026-07-23):** bant çeşitlendirme + segment invariant elle
      denetlendi. 1 CONFIRMED bug bulunup düzeltildi: `unroutableStopCount` plan'daki nil'lerden
      sayılıyordu — konum yokken hesaplanan rotada (plan[0]=nil, bilinen meşru durum) tüm duraklar
      koordinatlı olsa bile sahte "konumu yok" uyarısı üretirdi; sayaç artık doğrudan
      `routePlaces.filter { $0.coordinate == nil }` ve guard'dan ÖNCE senkron set ediliyor
      (erken-çıkışta da uyarı görünür). +3 regresyon testi → **137/137 yeşil**.
      `unroutableStopCount` @Published istisnası ONAYLANDI (rota-verisi state'i, failedLegCount'un
      eşi; navigasyon state'i değil). Kalan: XcodeBuildMCP simülatör GPS doğrulaması → yeni oturumda
      (MCP bu oturumda yüklü değil).

**Ferhat:**
- [ ] Beta Public Link'i en az 10-20 kişiye dağıt (arkadaşlar + 1-2 gezi grubu); geri bildirim topla

## FAZ 3 — Anı Günlüğü: viral çekirdek — KOD TAMAMLANDI 2026-07-23 (Sonnet, otonom oturum)

Polarsteps'in kanıtladığı model: gezi otomatik belgelenir → anıya dönüşür → paylaşılır.

- [x] `RatingSheetView`'e foto çekme/ekleme satırı (kamera+galeri, durak başına en fazla 3),
      `RouteSummaryViewModel.stopPhotos` state'i + `alsoSaveAsPlacePhoto` toggle'ı
- [x] `RouteHistory.memoryPhotosData` (Data?, hafif migration) + `RouteMemoryPhoto` struct
      (stopIndex/stopName/fileName) + encode/decode yardımcıları
- [x] `RouteMemoryStoring`/`DefaultRouteMemoryStore` (`Documents/RouteMemories/<historyID>/`,
      mekan fotoğrafından AYRI depo) + ortak `ImageDownscaler` (PlacePhotoService'ten çıkarıldı)
- [x] `MemoryCardComposing`/`DefaultMemoryCardComposer` — story (9:16) + post (4:5),
      `RouteMemoryMapSnapshotter` (MKMapSnapshotter + elle polyline çizimi, harita nil'ken de çalışır)
- [x] `RouteHistoryView` → Günlük yeniden tasarımı (foto'lu kart / düz satır) + `MemoryDetailView`
      ("Yeniden Paylaş"); "Hikayeni Paylaş" `RouteCompletionOverlay`'e eklendi — **soft paywall'ın
      üç dallı kapanış closure'ına (FAZ 1) DOKUNULMADI**, tasarım kısıtı korundu
- [x] Analytics: `memory_photo_added`, `memory_card_shared(format)` + 5 dil lokalizasyon
- [x] Veri silme akışı (`ProfileTab.deleteAllData`) her `RouteHistory`'nin `RouteMemories/`
      klasörünü de siliyor
- **Not:** Eski `RouteShareCard.swift`/`shareCompletionCard()` tek-foto paylaşımı yeni akışın
      SÜPERSETİ olduğu için devre dışı bırakıldı (dosya durduruluyor, silinmedi — ayrı temizlik kararı)
- 19 yeni test, ana dalda **181/181 yeşil**. Gerçek cihazda/simülatörde foto çekme akışı İNSAN
  TESTİ bekliyor (kamera simülatörde kısıtlı).

## FAZ 4 — İlk 30 Saniye + Hazır Rota Fabrikası (≈1 hafta kurulum + sürekli içerik)

Soğuk başlangıç ölüm nedenidir: mekanı olmayan kullanıcı boş harita görüp siler.

- [x] **"İlk rotanı 30 saniyede kur" akışı (Sonnet, 2026-07-23):** KASITLI TASARIM SAPMASI —
      OnboardingView İÇİNE konmadı (konum izni orada İSTENMEZ, bkz. mimari kısıt/geçmiş bug).
      Bunun yerine `FirstRouteSetupView`/`FirstRouteSetupViewModel`: HomeView placeStore boşken
      VE yalnızca bir kez (`pinly.firstRouteFlowShown`) tam ekran açılır, konum izni PermissionView'de
      zaten verilmiş olur. Şehir kataloğu varsa onu, yoksa `NearbySearching` ile karışık kategorilerden
      en yakın 5 öneriyi (paralel TaskGroup) gösterir; kabul → `SavedRoutesViewModel.loadAndStart`
      ile aynı desenle RouteSummaryView'e geçer. `starter_route_adopted` analytics event'i + 5 dil
      lokalizasyon eklendi.
- [x] **`StarterRouteService` genişletme (Sonnet, 2026-07-23):** `pinly-route-catalog-v1` formatı
      (`RouteCatalogEntry` + `LocalizedRouteText` 5 dil + `verified` bayrağı) eski `StarterRoutes.json`
      akışını KIRMADAN eklendi. `content/routes/tr/istanbul.json` → `Pinly/Resources/Routes/tr/istanbul.json`
      kopyalandı. Kategori `PlaceCategory.from(_:)` ile eşlenir (tanınmayan → `.general`, crash yok).
      Şehir algılama: `LocationManager.currentCity` (yeni, `currentDistrict`'e DOKUNMADAN eklendi —
      locality öncelikli okur) + `StarterCityMatcher` (saf fonksiyon, TR karakter normalize + eşleştirme).
      17 yeni test (katalog decode/kategori eşleme/şehir eşleştirme).
- [x] **Rota üretim hattı kuruldu ve çalışıyor (Sonnet, 2026-07-27):** taslak → `scripts/verify_routes.swift`
      (MKLocalSearch, PASS/NEAR/FAIL) → FAIL çıkan durakları gerçek koordinatla düzelt/çıkar →
      `verified:true` + `_meta.note`'a script özeti. İnsan göz kontrolü adımı bu turda OTOMATİK
      doğrulama script'i + Sonnet'in kendi çapraz kontrolüyle değiştirildi (Ferhat elle bakmadı) —
      istenirse ayrıca gözden geçirilebilir.
      **Kritik bug bulundu+düzeltildi:** `loadCityCatalog(city:)`, `StarterCityMatcher.matchCity`'yi
      `knownCities` parametresi VERMEDEN çağırıyordu → varsayılan `["istanbul"]`'a düşüyordu, yani
      `knownCatalogFiles`'a yeni şehir eklense bile o şehir asla eşleşmezdi (sessiz boş dönerdi).
      Artık bilinen şehir listesi katalog dosyalarının gerçek `city` alanından türetiliyor.
- [x] Dalga 1 (kısmi): **Ankara** (devreye alındı, 3 rota/9 durak, 0-125m sapma), **İzmir**
      (2 rota/7 durak — 3. taslak rota >2.5km kuralına takıldığı için hayali koordinatla
      doldurulmadan tamamen çıkarıldı), **Bursa** (3 rota/9 durak), **Antalya** (2 rota/6 durak
      — 2 durak jenerik isim yüzünden yanlış eşleşmişti, çapraz kontrolle düzeltildi) — hepsi
      `verified:true`, main'de. **Kalan:** Eskişehir, Gaziantep, Trabzon, Mardin, Kapadokya
      (İstanbul×ilçe bazında 8-10 rota genişletmesi de hâlâ yapılmadı) ≈ 60-80 rota hedefinden
      İstanbul+4 şehir/17 rota tamamlandı.
- [ ] Dalga 2: Avrupa 20 şehir (Paris, Roma, Barselona, Amsterdam, Berlin, Prag, Viyana, Budapeşte,
      Londra, Lizbon, Atina, Madrid, Floransa, Münih, Zürih, Kopenhag, Stokholm, Dublin, Brüksel,
      Selanik) ≈ 100+ rota — turist personası + RU/DE lokalizasyon kozunu oynar
- [ ] Katalog uzun vadede Supabase'e taşınır (FAZ 5) — app güncellemesi olmadan yeni rota eklenebilir

## FAZ 5 — Sosyal Katman: profil, paylaşım, fav (≈2-3 hafta, backend başlangıcı)

- [ ] **V1 (backend'siz, hemen):** ProfileTab'a "Rotalarım" bölümü — kaydettiği + paylaştığı rota
      sayıları (sayaçlar UserDefaults'ta zaten var), rota kartları
- [ ] **V2 (Supabase):**
  - [ ] Supabase MCP kur (`claude mcp add supabase ...`), proje oluştur (Ferhat: hesap açar)
  - [ ] Anonim auth → kullanıcı adı seçimi (zorunlu hesap YOK — sürtünme düşük kalsın)
  - [ ] Rota yayınlama: `SavedRoute.isPublic` + `supabaseId` alanları ZATEN modelde — publish servisi
        (`RouteFeedProviding` protokolü + `SupabaseRouteFeedService`)
  - [ ] Keşfet feed'i: şehre göre topluluk rotaları (hazır rota katalogu da aynı feed'den gelir)
  - [ ] **Fav sistemi:** rotayı favla → profilinde "Favlananlar"; rota kartında fav sayısı
  - [ ] **Kamu profili:** kullanıcı adı, paylaştığı rota sayısı, rotaları, toplam aldığı fav
  - [ ] **Moderasyon (App Review ZORUNLU şartı — UGC):** rota/profil raporlama butonu, engelleme,
        basit kelime filtresi, admin gizleme (Supabase dashboard)
  - [ ] RLS policy'leri + rate limit (spam rota yayınlamaya karşı)
- [ ] Influencer köprüsü: "adına rota paketi" — seçili kullanıcılara rozetli profil ("Rota Küratörü")

## FAZ 6 — UI/UX Yenileme (FAZ 3-5 ile paralel, toplam ≈1-2 hafta efor)

**İlke:** Seigaiha kimliği (krem/kağıt + sage + toz mavi + lacivert) KORUNUR — 2026'da herkes
"kişiliksiz beyaz minimal app" yaparken el yapımı/Japon esinli kimlik ayrıştırıcı. Üstüne iki katman:

**Güncel durum (Sonnet oturumu — `specs/FAZ6_UI_YON.md` sıralamasının 1. ve 2. maddeleri):**
Wow #1 (rota tamamlama sekansı) + haptic haritası + `contentTransition(.numericText())` UYGULANDI
(detay aşağıda `[x]`). Wow #2-6 ve Liquid Glass bu turda BAŞLANMADI — spec'teki öncelik sırasına
göre sıradaki oturumun kapsamı (aşağıdaki `[ ]` maddeler hâlâ geçerli, aynen bırakıldı).

- [ ] **iOS 26 Liquid Glass (koşullu):** hedef iOS 17 kalır; `if #available(iOS 26)` ile —
      harita üstü paneller/overlay'lerde `glassEffect`, PinlyTabBar'da glass varyant,
      `GlassEffectContainer` ile buton morfları. Xcode 26 ile derleme şart (Ferhat: Xcode güncel mi?).
- [x] **Wow anları (öncelik sırasıyla):**
  1. [x] Rota tamamlama sekansı: konfeti (var, dokunulmadı) → istatistikler km→dk→adım→ziyaret SIRAYLA
     0.15sn arayla spring+`contentTransition(.numericText())` ile 0'dan sayarak belirir → son
     istatistikten 0.6sn sonra "Hikayeni Paylaş" kartı alttan `spring(response:0.55,dampingFraction:0.75)`
     + hafif 3D `rotation3DEffect` ile yükselir → `HapticPlayer.routeCompleted()` (`.success`+0.1sn
     sonra `.impact(.soft)`). Reduce Motion: sayaçlar direkt final değere, kart sadece fade
     (`Pinly/Views/route/RouteCompletionOverlay.swift`).
  2. [ ] `matchedGeometryEffect` kart→detay geçişleri (Keşfet kartı → rota detayı) — ERTELENDİ
  3. [ ] Harita pin'lerinde spring "pop" + seçili pin nefes animasyonu — ERTELENDİ
  4. [ ] Keşfet'te `scrollTransition` parallax kartlar — ERTELENDİ
  5. [x] Haptic koreografi: merkezi `Pinly/Design/HapticPlayer.swift` (tüm UIKit generator'ları
     önceden `.prepare()` edilmiş `static let`) — durak varışı `.success`, rozet açılması
     `.success`+0.1sn `.impact(.rigid)`, seçim toggle `.selection`, rota başlatma `.impact(.medium)`,
     rota tamamlama `.success`+0.1sn `.impact(.soft)`. Favorileme haritada yok (özellik mevcut değil).
     Tüm eski ad-hoc `UI*FeedbackGenerator` çağrıları (10 dosya) bu merkezi yardımcıya taşındı.
  6. [ ] Onboarding'de WavePattern'in canlı dalgalanması (TimelineView) — ERTELENDİ
- [ ] Karanlık mod cila turu + app icon alternate (dark/tinted zaten var; sezonluk varyant değerlendir)
- [ ] Boş durum illüstrasyonları: SF Symbol'dan seigaiha-uyumlu mini vektör sahnelere (WavePattern dilinde) — ERTELENDİ
- [x] Erişilebilirlik (bu turun kapsamı — Wow #1 + haptic): Reduce Motion yolu, VoiceOver label'ları
      (paylaşım kartı + gated dismiss butonu), Dynamic Type güvenliği (`lineLimit`+`minimumScaleFactor`)
      `RouteCompletionOverlay`'de uygulandı. Genel Dynamic Type XL/VoiceOver turu (uygulama geneli)
      hâlâ ERTELENDİ.

## FAZ 7 — Pazarlama & Lansman (sürekli; FAZ 1 biter bitmez başlar)

- [ ] **ASO seti (Claude yazar, Ferhat ASC'ye girer):** 5 dilde başlık/alt başlık/keyword alanı/açıklama.
      TR: "gezilecek yerler, rota, yürüyüş, mekan kaydet"; EN: "city walking guide, istanbul routes";
      RU/DE turist keyword'leri ayrıca
- [ ] **Ekran görüntüleri:** 6.9"/6.5" 5'er adet × 5 dil — XcodeBuildMCP ile simülatörden otomatik çekim,
      çerçeve+başlık şablonu tek yerden
- [ ] **Video hattı:** haftada 2-3 TikTok/Reels. Format: "X şehrinde 1 gün: 5 durak" (30-45 sn) →
      son kare Pinly rota linki. Claude: senaryo + kanca metinleri; Ferhat: çekim/kurgu (CapCut şablonu bir
      kez kurulur). Uygulamanın ürettiği hikaye kartları hazır kreatif.
- [ ] **Influencer kiti:** deep link'li "senin rotan" paketi + 1 sayfalık tanıtım PDF'i; 10-50K takipçili
      10 TR gezi hesabına DM/mail (Ferhat gönderir, Claude metinleri yazar)
- [ ] **PR turu:** "Foursquare kapandı, Türkiye %9'luk pazardı" hikayesi → Webrazzi, ShiftDelete,
      DonanımHaber + Product Hunt lansmanı (EN). Claude: basın maili + PH sayfası taslağı.
- [ ] **Apple Search Ads:** $150-300/ay ile başla; markasız TR keyword seti + "foursquare alternative";
      ASO ile aynı kelimeler (paid indirme organik sıralamayı da iter)
- [ ] **Ölçüm çerçevesi (Firebase MCP ile Claude raporlar):** haftalık — indirme, D1/D7/D30 retention,
      rota tamamlama oranı, memory_card_shared, paywall funnel, crash-free oranı

---

## MCP / Tool Durumu

| Araç | Durum | Ne için |
|---|---|---|
| XcodeBuildMCP | ✔ kurulu | build/test/simülatör UI otomasyonu, ekran görüntüsü üretimi |
| Firebase MCP | ✔ kurulu | Crashlytics + Analytics raporları (FAZ 7 ölçüm) |
| RevenueCat MCP | kurulu, **OAuth bekliyor** (Ferhat: `/mcp`) | FAZ 1 ürün/entitlement/offering kurulumu |
| App Store Connect MCP | bekliyor (**Ferhat: .p8 anahtarı**) | TestFlight/review durumu, meta yönetimi |
| Supabase MCP | FAZ 5 başında kurulacak | sosyal backend şema/RLS yönetimi |
| Google Places API | **KULLANILMAYACAK** (karar) | puan gösterimi maliyeti ($35-40/1K çağrı) sürdürülemez; kendi topluluk puanımız + "Google Maps'te aç" düğmesi |

## Fiyatlandırma & Gelir Modeli

**Öneri:** Aylık **$4.99** / Yıllık **$39.99 (7 gün ücretsiz deneme — ana CTA bu)** / (opsiyonel, sonra)
Lifetime $79.99. **TR bölgesel fiyat manuel düşürülür:** aylık ₺129,99 / yıllık ₺799,99 civarı —
TR satın alma gücünde $4.99 karşılığı tam TL fiyat dönüşümü öldürür. Apple Small Business Program
(ilk $1M'da %15 kesinti) → net %85. Reklam geliri: free kullanıcı başına ay ~$0.02-0.05 (TR eCPM düşük,
AB/US ~2-3×).

Varsayımlar: ödeyenlerin %40'ı yıllık (aylığa amorti $3.33), %60'ı aylık; TR ağırlıklı senaryolarda
blended aylık ARPU ≈ $3.2, karışık pazarda ≈ $3.6, globalde ≈ $4.0. Dönüşüm: kötü %1 / gerçekçi %2 / iyi %3.

| Senaryo | Aktif kullanıcı | Pro (%) | Abonelik geliri/ay (net) | Reklam/ay | **Toplam/ay** |
|---|---|---|---|---|---|
| 1. TR çekirdek (beta+3 ay) | 5.000 | 75 (%1,5) | ~$205 | ~$150 | **~$350** |
| 2. TR yayılım (6-9 ay) | 25.000 | 500 (%2) | ~$1.360 | ~$740 | **~$2.100** |
| 3. TR + turist (12-18 ay) | 100.000 | 2.500 (%2,5) | ~$7.650 | ~$3.900 | **~$11.500** |
| 4. Global (24-36 ay) | 500.000 | 15.000 (%3) | ~$51.000 | ~$19.000 | **~$70.000** |

Okuma: hedefteki $8-15K/ay bandı Senaryo 3'te yakalanıyor — yani **100K aktif** (indirme değil!)
kullanıcı gerekiyor; bu da FAZ 3-4-7'nin (anı kartı viral döngüsü + hazır içerik + video hattı)
neden fiyatlandırmadan daha kritik olduğunu gösterir. En oynak kaldıraç dönüşüm oranı (%1↔%3 = 3×);
onu da en çok yıllık+deneme kurgusu ve paywall zamanlaması etkiler.

## Sıralama & Takvim (öneri)

1. **Hafta 1:** FAZ 1 (RevenueCat) + FAZ 2 (bug turu) → Build 4 TestFlight
2. **Hafta 2-3:** FAZ 3 (Anı Günlüğü) + FAZ 6 wow #1-2 → Build 5
3. **Hafta 3-4:** FAZ 4 (onboarding + TR rota dalga 1) + FAZ 7 ASO/ekran görüntüsü → **App Store'a SUBMIT**
4. **Hafta 5-8:** FAZ 5 (Supabase sosyal) + Avrupa rota dalga 2 + video/PR hattı sürekli
5. Lansman sonrası: haftalık metrik raporu → plana revizyon

## Ferhat'ın Yapacakları (konsolide)

1. `/mcp` → revenuecat OAuth (5 dk)
2. RevenueCat hesabı + ASC API anahtarı (.p8) üretip paylaş (15 dk)
3. ASC'de abonelik ürünleri onayı (Claude yönlendirir)
4. Sandbox test hesabı
5. Beta Public Link'i 10-20 kişiye dağıt
6. Xcode 26 kurulu mu kontrol (Liquid Glass için)
7. Rota kataloğu göz kontrolü (dalga başına ~30 dk)
8. Video çekim/kurgu (Claude senaryoları verir) + influencer DM'leri
9. Supabase hesabı (FAZ 5'te)
10. Büyük tasarım kararlarında AskUserQuestion'lara cevap
