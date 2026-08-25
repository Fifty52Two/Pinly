# Pinly V1 Release QA Matrix

Son güncelleme: 2026-08-25  
Build gerçeği: Debug `build-for-testing` ve clean-checkout Release simulator build başarılı. Bu makinedeki CoreSimulator test runner uygulamayı başlatamadığı için “unit testler çalıştı” denmez.

Durum anahtarı: **PASS** otomatik/yerel kanıt var; **MANUAL** gerçek cihaz/sandbox gerekir; **BLOCKED** production girdisi yok; **N/A V1** erişilemez özellik.

## P0 — submission öncesi kesin geçmeli

- **PASS — Clean checkout:** izlenen `Config.xcconfig`, `Package.resolved` ve shared workspace ile Release simulator compile.
- **PASS — Test target compile:** tüm app ve unit-test kaynakları iPhone 16 Pro / iOS 18.6 hedefinde `build-for-testing` ile derlendi.
- **BLOCKED — Otomatik test execution:** yerel CoreSimulator runner hang/corrupt runtime sorunu. Temiz CI runner sonucu zorunlu kanıt kabul edilecek.
- **BLOCKED — Release preflight:** production website host, numeric App Store ID, production interstitial unit ID ve final legal metinler eksik.
- **MANUAL — Archive:** gerçek signing/team ile Generic iOS Device Release archive; dSYM, embedded entitlements, privacy report ve validation.
- **MANUAL — Fresh install:** onboarding → profil/skip → location allow/deny → home; hiçbir crash veya sonsuz spinner olmamalı.
- **MANUAL — Core route:** place add/edit/delete, category, reorder, route calculation, deviation/recalculation, foreground/background navigation, complete/abort.
- **MANUAL — Purchases:** monthly/yearly offer, eligible/ineligible trial, buy, cancel, restore, refund/revoke, grace period, offline launch.
- **MANUAL — Ads/consent:** UMP required/not-required/error, ATT allow/deny, privacy options reopen; Free cap 7 dakika ve 2/session; Pro sıfır reklam.
- **MANUAL — Privacy:** exact-location/Health/profile/photos/notes leakage için device network capture; App Store label ile archive privacy report eşleşmesi.
- **MANUAL — Legal links:** paywall ve Profile içinden HTTPS privacy/terms/support/choices; tüm URL'ler production'da 200 ve mobil okunabilir.

## Cihaz ve OS kapsaması

- **MANUAL:** iPhone SE sınıfı küçük ekran / iOS 17 minimum.
- **MANUAL:** iPhone 16 Pro / güncel iOS.
- **MANUAL:** büyük ekran iPhone Pro Max.
- **MANUAL:** light mode (production tek tema), Dynamic Type XXL ve Bold Text.
- **MANUAL:** VoiceOver ile onboarding, place form, route start/stop, paywall, restore ve privacy choices.
- **MANUAL:** Türkçe ve İngilizce tam akış; Almanca/İspanyolca/Rusça smoke ve taşma.
- **MANUAL:** zayıf ağ, uçak modu, düşük pil, konum kapalı, precise location kapalı.

## Özellik senaryoları

### Onboarding ve izinler

- Bildirim izni onboarding'de çıkmamalı; haftalık rapor CTA'sında çıkmalı.
- Reklam/UMP/ATT onboarding veya profil ekranının üstüne gelmemeli.
- Bilinen 16 yaş altına ATT çıkmamalı; 13 yaş altı child-directed reklam config'i almalı.
- Konum reddinde uygulama çökmemeli; ayarlara yönlendirme ve koordinatsız kullanım anlaşılır olmalı.
- HealthKit reddinde rota tamamlama çalışmalı, sadece step/distance boş kalmalı.

### Mekan, import ve dosya güvenliği

- Kamera, galeri, adres arama, harita pini, mevcut konum ve koordinatsız mekan.
- QR/URL yanlış scheme/host, boş isim, aşırı uzun alan, NaN/Inf/out-of-range koordinat reddi.
- Route payload 64 KB üstü ve 50 durak üstü reddi; bir bozuk durak varsa tüm rota reddi.
- Swarm dosyası 10 MB üstü reddi; en fazla 500 benzersiz check-in.
- PDF/GPX dosya adı slash/colon vb. karakterlerde güvenli; XML özel karakterleri escaped.

### Navigation ve yaşam döngüsü

- Navigasyon başlarken veya link/QR paylaşırken interstitial gösterilmemeli.
- Background konum yalnız aktif navigasyonda açık; stop/complete sonrası kapanmalı.
- Live Activity başlat/güncelle/bitir; app deep link geri dönüşü.
- 2 saatlik otomatik konum durdurma, app terminate/relaunch ve stale state.

### Monetizasyon

- Free mekan sayısı sınırsız; 20-place gate hiçbir yerde geri dönmemeli.
- Pro gate yalnız GPX/PDF ve reklamsızlıkta.
- Paywall fiyatı StoreKit localized string; sabit fiyat yok.
- Trial rozeti sadece RevenueCat `.eligible` sonucunda.
- Satın alma sonrası aktif `pro` entitlement yoksa sheet kapanmamalı.
- Export paywall satın alımından sonra bekleyen GPX/PDF işlemi otomatik devam etmeli.

### Social V1 hard-off

- Community alanı yalnız “Çok yakında”; feed/network yok.
- Publish/favorite/report/block/shared-route/Apple login normal navigasyondan erişilemez.
- `pinly://sharedroute` hiçbir hesap veya ağ yazımı başlatmaz.
- NoOp mutasyon sahte başarı değil `disabled` hatası üretir.

## Website QA

- **PASS:** TR/EN home + privacy/terms/support/privacy-choices yerel HTTP 200.
- **PASS:** Desktop ve 390 px mobil görünüm; yatay overflow yok; gerçek uygulama screenshot'ı kullanılıyor.
- **PASS:** 20-place limit, hard-coded price, offline maps ve doğrulanmamış `pinly.app` iddiası yok.
- **BLOCKED:** legal identity/email/address/domain/App Store URL sağlanmadan `data-release-ready=false`, `noindex` ve draft uyarıları kaldırılmaz.
- **MANUAL:** production SSL, canonical/hreflang/OG, sitemap/robots, 404, analytics/cookie davranışı ve Lighthouse.

## Çıkış kriteri

Release candidate ancak şu dört kanıt aynı build numarasıyla arşivlendiğinde gönderilir:

1. CI unit test sonucu yeşil.
2. Gerçek cihaz P0 manual suite imzalı/dated PASS.
3. Sandbox subscription + AdMob consent/reklam kanıtı PASS.
4. `scripts/release_preflight.sh` sıfır exit ile PASS ve App Store Connect privacy/legal metadata ikinci kişi kontrolü tamam.
