# Pinly V1 App Store Submission

Bu belge submission çalışma kâğıdıdır; `docs/FINAL_RELEASE_STATUS.md` tek karar kaynağıdır.

## Nihai ürün gerçeği

- Ana döngü: save → plan → walk → remember.
- Free: sınırsız mekan, rota planlama, navigasyon ve core Pinly.
- Pro: sıfır reklam, GPX export, PDF export.
- V1: hesap, public profile, community feed, social publish ve cloud sync yok.
- Demo account gerekmez.

## Gerekli kullanıcı girdileri

- Final public app name:
- Numeric App Store ID:
- Bundle ID confirmation:
- Version/build:
- Publisher/legal name:
- Support/privacy email:
- Country/address where applicable:
- Production domain:
- Primary/secondary category:
- Target countries:
- Age rating answers:

## App Review notes draft

1. Home → Mekan Ekle ile bir mekan kaydedilir; hesap gerekmez.
2. Rota Planla/Rota Tasarla ile duraklar seçilir ve yürüyüş sırası oluşturulur.
3. Route Summary üzerinden navigasyon başlatılır. Konum yalnız ilgili deneyim için istenir; aktif navigasyon background location ve Live Activity kullanabilir.
4. GPX/PDF butonları Free kullanıcıda Pinly Pro paywall'ını açar. Fiyat ve trial uygunluğu StoreKit/RevenueCat'ten gelir.
5. Restore Purchases paywall içinde ve Profile → Pinly Pro yolunda bulunur.
6. HealthKit yalnız kullanıcı izin verirse tamamlanan rotanın adım/mesafe özetini okumak için kullanılır; uygulama HealthKit'e yazmaz ve medical functionality sunmaz.
7. Social/community V1'de kapalıdır; demo account yoktur ve public upload yapılmaz.

Final not, gerçek build/ürün ve reviewer erişim yollarıyla yeniden doğrulanmalıdır.

## Archive kontrolü

- Version/build ve signing.
- Entitlements: HealthKit, background location, Live Activities.
- `PrivacyInfo.xcprivacy` ve Organizer Privacy Report.
- Firebase client configuration.
- RevenueCat production public SDK key/offering/entitlement.
- AdMob production App ID + interstitial unit; test ID yok.
- Production website host, legal/support URL'leri ve numeric App Store ID.
- `.claude`, `.codex`, local config ve debug artifact `.app` içinde yok.

## Submission gate

Şunların her biri `docs/FINAL_RELEASE_STATUS.md` içinde PASS olmadan submit edilmez: CI, Debug tests, Release archive, RevenueCat sandbox, Ads/UMP/ATT, App Privacy, public website/legal/support, full screenshot set, brand/name review, physical-device QA ve TestFlight acceptance.
