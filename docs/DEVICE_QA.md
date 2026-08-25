# Pinly V1 Device QA Record

Bu belge kullanıcı tarafından exact Release Candidate build üzerinde doldurulur. Boş veya tahmini kayıt PASS sayılmaz.

## Build kimliği

- Version:
- Build:
- Commit:
- TestFlight build:
- Tarih/saat:
- Tester:

## Cihaz matrisi

| Cihaz | iOS | Dil | Light/Dark | Sonuç | Kanıt/not |
|---|---|---|---|---|---|
| Küçük/eski desteklenen iPhone |  |  |  | NOT STARTED |  |
| Güncel standart iPhone |  |  |  | NOT STARTED |  |
| Güncel Pro/Pro Max |  |  |  | NOT STARTED |  |

## Gerçek yürüyüş 1 — 30–45 dakika

- Başlangıç/bitiş:
- Süre:
- Pil başlangıç/bitiş:
- GPS/arrival sonucu:
- Reroute süresi:
- Screen lock/background/foreground:
- Live Activity:
- Ağ kesintisi/weak signal:
- Pause/resume/completion:
- Fotoğraf/memory:
- HealthKit allowed/denied:
- Crash/UI glitch:
- Sonuç: `NOT STARTED`

## Gerçek yürüyüş 2 — 60–120 dakika

Aynı alanlarla ayrı kayıt eklenmelidir. Sonuç: `NOT STARTED`.

## RevenueCat sandbox

| Senaryo | Sonuç | Kanıt/not |
|---|---|---|
| Free → GPX → paywall → yearly purchase → GPX hemen export | NOT STARTED |  |
| Reinstall → Restore Purchases → Pro hemen aktif | NOT STARTED |  |
| Expiration/cancellation/renewal → entitlement refresh | NOT STARTED |  |
| Geçici ağ yok → crash/yalan satın alma yok | NOT STARTED |  |

## Ads / consent / ATT

| Senaryo | Sonuç | Kanıt/not |
|---|---|---|
| Debug test reklam kimliği | NOT STARTED |  |
| Release production kimliği | NOT STARTED |  |
| UMP required/not-required/error | NOT STARTED |  |
| ATT allow/deny ve doğru zamanlama | NOT STARTED |  |
| Privacy options yeniden açılır | NOT STARTED |  |
| Pro'da sıfır interstitial | NOT STARTED |  |
| Navigation start/active navigation'da sıfır interstitial | NOT STARTED |  |
| Free 7 dakika / max 2 session | NOT STARTED |  |

## Permissions / accessibility

Konum, precise location, HealthKit, kamera/fotoğraf ve notification allow/deny ayrı ayrı denenmeli. Largest Dynamic Type, Bold Text, Reduce Motion ve VoiceOver spot-check; onboarding, Home, Nearby, Discover, RouteSummary, Paywall, Badges, Weekly Report ve Profile üzerinde kritik clipping/erişilemez kontrol olmamalı.

## Export

- GPX bağımsız bir GPX uygulamasında rota/koordinat/waypoint/encoding doğrulandı: `NOT STARTED`.
- PDF Files, Preview, AirDrop ve en az bir mesajlaşma share hedefinde açıldı: `NOT STARTED`.

## Sign-off

- P0 blocker sayısı:
- Açık P1 sayısı:
- Tester imzası/tarih:
- RC physical-device gate: `NOT STARTED`
