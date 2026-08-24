# FAZ 1 — RevenueCat Karar Katmanı (Fable) + Uygulama Spec'i (Sonnet)

## MAĞAZA KURULUMU TAMAMLANDI (2026-07-23) — Sonnet için gerçek değerler
- RevenueCat proje `proj5955a1be`, App Store app `appc32f960641` (com.farad.pinly), her iki
  ASC anahtarı işli. Public SDK key `Config.xcconfig` içindeki `RevenueCatAPIKey`'den
  Info.plist'e enjekte edilir (bu dosya `.gitignore`'da). RevenueCat'in public SDK key'i
  tasarım gereği istemcide görünür bir değerdir, yine de repoya yazılmaz — sırların tek
  yeri `Config.xcconfig`.
- Entitlement **`pro`** (`entlb8f28bde64`) · Offering **`default`**: `$rc_monthly` + `$rc_annual`
  paketlerinde gerçek ürünler; Test Store örnek ürünleri de `pro`ya bağlı (StoreKit'siz hızlı test).
- ASC: abonelik grubu "Pinly Pro", 5 dil lokalizasyon, 175 bölge, yearly'de 7 gün FREE_TRIAL —
  hepsi girildi. Tek eksik review screenshot (paywall UI bitince yüklenecek; o yüzden
  MISSING_METADATA görünür, sandbox akışını ENGELLEMEZ).
- Sandbox test hesabı: App Store Connect → Users and Access → Sandbox Testers (Türkiye).
  Hesap adresi/parolası repoya YAZILMAZ.

## Ürün kurgusu (GÜNCEL — gerçek fiyatlar, 2026-07-23 Ferhat kararı)
- Entitlement: `pro` · Offering: `default` · Ürünler: `pinly_pro_monthly` **$2.99 / ₺149,99**,
  `pinly_pro_yearly` **$29.99 / ₺1.499,99** + **7 gün ücretsiz deneme** (introductory offer,
  yearly'de). Paywall'da varsayılan seçili plan: YILLIK ("7 gün ücretsiz dene" CTA'sı).
  Aşağıdaki metinlerdeki ₺799,99/₺129,99 örnekleri ESKİ — zaten fiyat metne gömülmez,
  `localizedPriceString` ile dinamik gelir.
- Lifetime ŞİMDİ YOK (ileride kampanya aracı olarak saklanıyor).
- ASC'de Billing Grace Period AÇIK (16 gün).

## Mimari kararlar
1. `RevenueCatEntitlementService: EntitlementProviding, ObservableObject` — YENİ dosya,
   `EntitlementService.swift`'e dokunulmaz; `LocalEntitlementService` DEBUG/preview/test'te kalır.
   `PinlyApp`'te: `#if DEBUG` Local, değilse RevenueCat (composition root'ta TEK satır seçim).
2. API key `Info.plist`'te `RevenueCatAPIKey` (koda gömme); `Purchases.configure` PinlyApp init'te,
   `Purchases.logLevel = .warn`.
3. **isPro kaynağı:** `customerInfoStream` dinlenir → `entitlements["pro"].isActive` →
   `@Published` yansıtılır + `pinly.isPro` anahtarına AYNA olarak yazılır (offline ilk açılışta
   son bilinen değerle başlamak için — flicker önlenir). `isPro` setter'ı RevenueCat modunda
   **no-op + assertionFailure(DEBUG)**: gerçeğin kaynağı RevenueCat'tir, kimse elle set edemez.
4. **Placeholder paywall mirası:** beta kullanıcılarında `pinly.isPro=true` kalmış olabilir (sahte
   "Pro'ya Geç" butonu). RevenueCat modunda ilk `customerInfo` geldiğinde ayna DEĞER ÜZERİNE YAZILIR
   → sahte Pro'lar otomatik temizlenir. Beta boyunca mağduriyet yok: `unlimitedPlacesInBeta`
   TestFlight'ta zaten tüm limitleri kapatıyor; App Store build'inde bayrak kendiliğinden false
   (Release + sandbox receipt algısı — App Store receipt'i sandbox değil).
5. **Restore:** sadece manuel buton (`restorePurchases`). Otomatik restore YOK.
6. DEBUG test: `Pinly.storekit` StoreKit Configuration dosyası + scheme'e bağlama; TestFlight
   sandbox'ta gerçek akış.
7. Analytics: `paywall_shown(source)` MEVCUT; eklenecek: `trial_started`, `purchase_completed(product)`,
   `restore_completed`. RevenueCat→Firebase entegrasyonunu AÇMA (çifte sayım); event'ler client'tan.

## Paywall zamanlama stratejisi (dönüşümün asıl kaldıracı)
- 7 gate mevcut (limit aşımı) — bunlar kalır; kaynak parametresi zaten var.
- YENİ tek proaktif nokta: **ilk rota TAMAMLANDIKTAN sonra** (değer anı) kutlama akışı bittikten
  sonra bir kez soft paywall (`source: "first_route_completed"`, `pinly.softPaywallShown` ile tek
  seferlik). Onboarding'de paywall YOK (değer görmeden fiyat gösterme — ilk izlenim yakılmaz).
- Kapatması kolay (X sağ üst, ilk saniyeden), koyu desenler YOK — App Review 3.1.2 temiz.

## Paywall metni (Fable — 5 dil, Localizable'a Sonnet ekler)
- Başlık TR: "Sınırsız keşif" / EN: "Explore without limits" / ES: "Explora sin límites" /
  DE: "Entdecken ohne Grenzen" / RU: "Исследуй без границ"
- Değer satırları (3): sınırsız mekan · GPX/PDF dışa aktarma · reklamsız deneyim
  (TR: "Sınırsız mekan kaydet" / "Rotalarını GPX ve PDF olarak dışa aktar" / "Reklamsız kullan")
- CTA TR: "7 gün ücretsiz dene" · alt satır: "Sonra yılda ₺799,99 — istediğin zaman iptal et"
  (fiyat StoreKit'ten dinamik: `localizedPriceString`, metne gömme!)
- İkincil: "Aylık ₺129,99" · "Satın alımları geri yükle" — EN/ES/DE/RU karşılıkları Sonnet'e
  bırakılmaz, Fable çeviri tablosunu uygulama sırasında verir (ton kontrolü).

## Sonnet görev listesi — TAMAMLANDI 2026-07-23 (aynı gün, Ferhat modeli Sonnet'e çevirdi)
- [x] SPM: RevenueCat ürünü Pinly + PinlyTests target'larına link (pbxproj elle düzenlendi)
- [x] `RevenueCatEntitlementService` (yukarıdaki 3-4-5 kararlarıyla) + birim test edilebilir çekirdek:
      `EntitlementMapper.isPro(customerInfo:)` saf fonksiyon + 4 test (`EntitlementMapperTests.swift`)
- [x] PinlyApp configure + composition root seçimi (`#if DEBUG` Local/RevenueCat; Purchases SDK
      DEBUG/Release farketmeksizin her zaman configure — StoreKit Config testi DEBUG'da da çalışsın)
- [x] PaywallView: offering çek → paket kartları (yıllık önseçili, gerçek intro offer'dan deneme
      rozeti), 3 TODO'nun purchase/restore'a bağlanması, yükleniyor/hata durumları ("Şu an
      mağazaya ulaşılamıyor" + tekrar dene)
- [x] Soft paywall tetikleyicisi (first_route_completed, tek seferlik, review promptuyla çakışmıyor)
- [x] Yeni analytics event'leri + `Pinly.storekit` dosyası + scheme bağlama (Launch+Test action)
- [ ] Sandbox uçtan uca: satın al → isPro ayna → gate'ler açık → iptal → grace davranışı —
      İNSAN TESTİ GEREKİYOR (gerçek Apple ID + sandbox oturumu otomasyonla simüle edilemez).
      Kod-seviyesinde build+143/143 test doğrulaması XcodeBuildMCP ile yapıldı.

**Kabul ölçütü — kod seviyesinde sağlandı, sandbox insan testi bekliyor:** StoreKit config ile
DEBUG'da deneme başlatılınca PaywallView `entitlements.isPro = true` set eder (DEBUG'da bu gerçek
bir toggle çünkü composition root Local kullanır); Release'te aynı satır no-op ama
`customerInfoStream` zaten aynı anda `pinly.isPro`yu güncelliyor — iki build konfigürasyonu da
gate'lerin açılmasını sağlıyor (üçü de aynı UserDefaults anahtarını okuyor). Restore çalışıyor
(`purchases.restorePurchases()` → aynı mirror akışı). Uçak modunda açılışta son bilinen değer
korunuyor (`RevenueCatEntitlementService.init` önce UserDefaults'tan okuyor, stream sonra günceller).
Sahte `pinly.isPro=true` Release'te ilk `customerInfoStream` olayında RevenueCat gerçeğiyle eziliyor.
Bu mantığın gerçek cihaz/sandbox'ta fiilen çalıştığı DOĞRULANMADI — sıradaki insan adımı bu.
