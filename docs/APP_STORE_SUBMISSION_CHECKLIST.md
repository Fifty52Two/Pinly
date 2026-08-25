# Pinly V1 App Store Submission Checklist

## Bloklayıcı production girdileri

- [ ] `SITE_REQUIRED_INPUTS.md` içindeki tüzel/gerçek kişi unvanı, veri sorumlusu, adres, ülke, destek ve privacy e-postası, hukuk/yaş kararı tamamlandı.
- [ ] Production domain ve HTTPS hazır; TR/EN legal/support sayfaları hukukça onaylandı.
- [ ] Numeric App Store ID üretildi; `Config.local.xcconfig` içinde host ve ID girildi.
- [ ] Production AdMob app ID ve interstitial unit ID local config'e girildi; test ID kalmadı.
- [ ] `scripts/release_preflight.sh` PASS.

## Build ve signing

- [ ] Aynı RC commit'i `macos-26` + sabit Xcode 26.6 CI'da Debug tests ve Release compile job'larını geçti; loglar Apple Swift 6.3.3 ve iOS 26.5 SDK'yı doğruluyor.
- [ ] App Store'a gönderilecek archive Xcode 26 veya sonrası ve iOS 26 SDK veya sonrası ile üretildi (28 Nisan 2026 upload şartı).
- [ ] Bundle ID `com.farad.pinly`, Live Activity extension ID ve App Store kaydı eşleşiyor.
- [ ] Marketing version `2.0`; build number benzersiz ve artırılmış.
- [ ] Distribution certificate/profile, HealthKit ve Live Activities capability doğru.
- [ ] Release archive gerçek cihaz hedefinde oluşturuldu; Validate App başarılı.
- [ ] dSYM upload ve Crashlytics script archive'da başarılı.
- [ ] Exported archive privacy report `docs/APP_PRIVACY_MATRIX_FINAL.md` ile karşılaştırıldı.
- [ ] `ITSAppUsesNonExemptEncryption = NO` kullanım şekliyle teyit edildi.

## StoreKit / RevenueCat

- [ ] Monthly/yearly subscription ürünleri Ready to Submit/Approved durumda.
- [ ] RevenueCat current offering package mapping doğru.
- [ ] İki ürün de `pro` entitlement'a bağlı.
- [ ] Trial yalnız App Store Connect'te gerçekten tanımlıysa metadata'da anılıyor.
- [ ] Sandbox: buy, restore, cancellation, expiry, grace period, refund/revoke ve offline entitlement testi geçti.
- [ ] Agreements, Tax and Banking eksiksiz.

## Ads, privacy ve yaş

- [ ] AdMob app App Store kaydıyla linklendi; app-ads.txt gerekiyorsa production domain'e eklendi.
- [ ] EEA/UK/CH consent, US states ve IDFA mesajları yayınlandı ve gerçek cihazda test edildi.
- [ ] Mediation varsa her adapter'ın consent/TFUA iletimi doğrulandı.
- [ ] App Store privacy answers en geniş SDK davranışına göre girildi: Device ID tracking dahil.
- [ ] Age rating questionnaire, unrestricted web access/UGC/ads/health/location cevapları V1 gerçeğiyle uyumlu.
- [ ] Minimum yaş ve 16 yaş altı mixed-audience yaklaşımı hukukça onaylandı.

## Metadata ve creative

- [ ] `marketing/APP_STORE_METADATA_TR_EN.md` placeholder'ları production URL'lerle değiştirildi.
- [ ] Title/subtitle/keywords karakter limitleri App Store Connect'te yeniden kontrol edildi.
- [ ] `docs/SCREENSHOT_REQUIREMENTS.md` içindeki 9 sahne gerçek build'den, doğru lokalizasyon ve cihaz ölçülerinde üretildi.
- [ ] App icon tüm required size/appearance kontrollerinden geçti.
- [ ] Description, website, paywall ve StoreKit aynı Free/Pro gerçeğini anlatıyor.
- [ ] Sabit fiyat veya herkese trial vaadi yok.
- [ ] Review notes ve gerekiyorsa sandbox reviewer credentials eklendi.

## Manual QA ve gönderim

- [ ] `docs/RELEASE_QA_MATRIX.md` P0 senaryoları aynı RC build'de geçti.
- [ ] CI tests yeşil; test result artifact saklandı.
- [ ] Crash-free smoke: fresh install, upgrade, offline, permission deny, five languages.
- [ ] Privacy/terms/support/choices linkleri app içinde ve App Store metadata'da açılıyor.
- [ ] Production backendler üzerinde yalnız gerekli read-only doğrulamalar yapıldı; sosyal V1 sayaçları artmıyor.
- [ ] Phased release ve automatic release kararı verildi; monitoring owner ve rollback criteria yazıldı.

## İlk 72 saat izleme

- Crash-free users ve fatal top issues.
- Onboarding completion → first place → first route → navigation start → route completion funnel.
- Paywall view → trial/purchase → verified entitlement; restore hata oranı.
- Ad request/fill/show/dismiss, session başına interstitial ve Pro'da yanlış reklam sinyali.
- App Store review/ratings ve support talepleri.
- P0 crash, satın alma kilidi, veri sızıntısı veya navigasyon güvenlik hatasında release pause/rollback.
