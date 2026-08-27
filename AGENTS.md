# AGENTS.md

Bu depo için tek kaynak **[CLAUDE.md](CLAUDE.md)**'dir — mimari, katmanlar, veri akışı,
bilinen kırılganlıklar ve yapılacaklar orada. Codex dahil her ajan önce onu okur.

Bu dosya daha önce CLAUDE.md'nin elle tutulan bir kopyasıydı ve ayrıştı: silinmiş kavramları
(20 mekanlık `freeLimit`, "RevenueCat gelince", arşive kaldırılmış `ROADMAP.md`) güncel diye
tarif ediyordu. Kopya yerine işaretçi tutuluyor ki bir daha ayrışmasın.

## Hızlı başlangıç

```bash
# Derleme (simülatör)
xcodebuild -scheme Pinly -destination 'platform=iOS Simulator,name=iPhone 17' build

# Tüm testleri koştur
xcodebuild -scheme Pinly -destination 'platform=iOS Simulator,name=iPhone 17' test

# Tek test sınıfı
xcodebuild -scheme Pinly -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:PinlyTests/RouteManagerDeviationTests
```

> **StoreKit işleri iOS 18.5'te koşturulmalı** (`name=iPhone 16,OS=18.5`) — iOS 26
> simülatöründe StoreKit Configuration ürün sunmuyor, `StoreKitConfigFileTests` yanlış
> negatif verir.

## Çalıştırmadan önce gereken gizli dosyalar

İkisi de `.gitignore`'da; repoda yok, her geliştirici kendi kopyasını oluşturur.
Eksikse proje **hiç derlenmez** (`Config.xcconfig`) veya açılışta çöker
(`GoogleService-Info.plist`).

| Dosya | İçerik |
|---|---|
| `Config.xcconfig` (repo kökü) | `GAD_APPLICATION_IDENTIFIER`, `REVENUECAT_API_KEY` |
| `Pinly/GoogleService-Info.plist` | Firebase Console'dan indirilir |

## Değişmez kurallar

- Commit mesajı: `tip: açıklama` (`feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`),
  tek satır, Türkçe, ne yapıldığını söyler.
- Yeni yetenek önce protokol, sonra somut servis, sonra ViewModel'e enjeksiyon (DIP).
- Renkler `Pinly/Design/Theme.swift`'ten alınır, view içinde hardcode edilmez.
- SourceKit'in "Cannot find X in scope" hataları FALSE POSITIVE'dir — kod değiştirme.
- Büyük tasarım/UX kararları uygulanmadan önce kullanıcıya sorulur.
