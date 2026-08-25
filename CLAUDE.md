# Pinly Repository Guide

Bu dosya kısa bir yönlendirme katmanıdır. Güncel ürün ve geliştirme gerçeği için:

1. `AGENTS.md`
2. `docs/FINAL_RELEASE_STATUS.md`
3. production Swift kodu ve testler
4. `README.md`

`docs/archive/` ve `specs/` tarihsel karar kaydıdır; bugünkü ürün davranışını tek başına tarif etmez.

## Release modu

- Aktif branch: `codex/release-hardening-v1`.
- V1 feature freeze içindedir; release blocker dışında özellik eklenmez.
- Social/community, hesap ve Supabase yazma yolları V1 production composition root'unda kapalıdır.
- Free: sınırsız mekan, rota planlama ve navigasyon.
- Pro: reklamsızlık, GPX ve PDF dışa aktarma.
- RevenueCat/StoreKit gerçek satın alma kaynağıdır; fiyatlar hardcode edilmez.
- Release reklam kimlikleri, website hostu ve App Store ID yalnız ignored `Config.local.xcconfig` üzerinden gelir.

## Güvenli doğrulama

```bash
xcodebuild -project Pinly.xcodeproj -scheme Pinly \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build-for-testing

xcodebuild -project Pinly.xcodeproj -scheme Pinly -configuration Release \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

./scripts/release_preflight.sh
```

Simulator adı yerelde farklıysa `xcrun simctl list devices available` çıktısından mevcut bir iPhone seç.

## Koruma kuralları

- Production veritabanı, dashboard, domain, App Store veya uzak geçmiş üzerinde kullanıcı onayı olmadan değişiklik yapma.
- `Config.local.xcconfig`, `.codex/`, `.claude/`, Google production client configleri ve credential dosyaları commit edilmez.
- Konum, HealthKit değeri, özel not, kullanıcı rota adı veya fotoğraf metadata'sını analytics parametresi yapma.
- Paywall yalnız bugün çalışan Pro faydalarını satar.
- Yayın kararı yalnız `docs/FINAL_RELEASE_STATUS.md` kanıtlarıyla verilir.
