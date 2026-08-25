# Pinly V1 — Final Release Status

Tek release kontrol merkezi. Son güncelleme: 25 Ağustos 2026. Branch: `codex/release-hardening-v1`.

Kurallar:

- Status yalnız `NOT STARTED`, `IN PROGRESS`, `PASS`, `FAIL` veya `BLOCKED BY USER` olabilir.
- Bir satır yalnız tekrarlanabilir kanıt varsa `PASS` olur.
- Bu belgeye link/screenshot/xcresult/gerçek cihaz kaydı eklenmeden dış aksiyonlar tamamlanmış sayılmaz.

| Area | Status | Owner | Blocking? | Evidence | Next Action |
|---|---|---|---|---|---|
| CI | BLOCKED BY USER | BOTH | Yes | Workflow clean checkout için resolve → build-for-testing → `PinlyTests` → xcresult/log artifact ve ayrı Release compile içeriyor. Public GitHub görünümünde açık PR yok; branch push workflow'u tetiklemez. | `codex/release-hardening-v1 → main` PR aç; iki job linkini buraya ekle. |
| Debug tests | IN PROGRESS | BOTH | Yes | `5e94876` baseline Debug `build-for-testing` başarılıydı; güncel çalışma ağacında Swift parse/plist/localization kontrolleri geçti. Sandbox SwiftPM/CoreSimulator'ı engellediği için execution sonucu yok. CI `test-without-building -only-testing:PinlyTests` çalıştıracak. | PR CI'daki Debug job'u yeşil olmalı; xcresult artifact linki eklenmeli. |
| Release compile | IN PROGRESS | BOTH | Yes | `5e94876` baseline clean simulator Release build başarılıydı. Güncel RC değişiklikleri henüz compile edilmedi; önceki kanıt yeni ağaca PASS taşımaz. | PR'daki generic simulator Release job yeşil olmalı. |
| Release archive | BLOCKED BY USER | BOTH | Yes | Signing/archive/Organizer doğrulaması yapılmadı. | Final production config ile Xcode Archive + Validate App; archive/build numarasını kaydet. |
| Social hard-off | PASS | CODEX | No | `SocialFeaturePolicy.isEnabledInV1 == false`; composition root yalnız NoOp servisleri inject ediyor; `SocialV1HardOffTests` kaynak kanıtı var. | CI test execution kanıtını ekle; Supabase geçmiş test verisini kullanıcı ayrıca denetlesin. |
| RevenueCat | BLOCKED BY USER | BOTH | Yes | Kodda offering, localized price, trial eligibility, verified entitlement, restore ve fail-safe config mevcut. Sandbox/TestFlight satın alma kanıtı yok. | A–D sandbox senaryolarını çalıştır ve sonuçları `docs/DEVICE_QA.md` içine kaydet. |
| Ads | BLOCKED BY USER | BOTH | Yes | Debug test ID; Release ID config'den; Pro/nav start/share reklamı yok; policy 7 dakika ve 2/session testli. Production ad unit boş. | AdMob production App ID/unit/account durumunu doğrula ve ignored config'e gir. |
| UMP | BLOCKED BY USER | BOTH | Yes | `canRequestAds` olmadan Mobile Ads başlamıyor; privacy-options yalnız SDK `.required` dediğinde görünür; çocuk/ergen flag'leri uygulanıyor. Dashboard/bölgesel gerçek cihaz kanıtı yok. | EEA/UK/CH ve US consent ayarlarını dashboard + cihazda doğrula. |
| ATT | BLOCKED BY USER | BOTH | Yes | ATT onboarding/profil öncesi istenmiyor; bilinen 16 yaş altına istenmiyor. Gerçek prompt timing kanıtı yok. | Temiz kurulum gerçek cihaz testi ve screenshot kaydı. |
| HealthKit | BLOCKED BY USER | BOTH | Yes | Yalnız step count + walking/running distance read; update usage metni kaldırıldı; denial core completion'ı engellemiyor. | Health allow/deny gerçek yürüyüş senaryolarını tamamla. |
| Location | BLOCKED BY USER | BOTH | Yes | İlk izin kararı ertelenebilir; navigation sırasında background tracking, stop/timeout cleanup kodu mevcut. Simulator fiziksel yürüyüş kanıtı değildir. | 30–45 ve 60–120 dakikalık gerçek yürüyüşleri kaydet. |
| Privacy Manifest | PASS | CODEX | No | `PrivacyInfo.xcprivacy` plist lint geçiyor; SDK davranışları ihtiyatlı en-geniş beyanla eşlendi; UserDefaults reason `CA92.1`. | Archive privacy report ile yeniden karşılaştır; uyuşmazlıkta PASS geri alınır. |
| Security repo sweep | PASS | CODEX | No | `scripts/security_sweep.sh` private-key/token, service-role, broad ATS ve hassas access-group taramasını geçti; plist/project lint temiz. | GitHub alert/branch protection ve dashboard rollerini kullanıcı doğrulasın. |
| Analytics funnel | PASS | CODEX | No | 12 zorunlu funnel eventi enum sözleşmesinde; kaynak/product dışında hassas parametre yok; event adları/parametreleri testlerde, first-place tek-sefer guard'ı kaynakta mevcut. | Firebase DebugView/production dashboard gerçek cihaz kanıtı ekle. |
| Accessibility | IN PROGRESS | BOTH | Yes | Kritik ikon-only kontroller etiketlendi; web keyboard focus/reduced-motion/responsive statik QA geçti. Fiziksel VoiceOver/Dynamic Type kanıtı yok. | `docs/ACCESSIBILITY_AUDIT.md` cihaz matrisini aynı RC build'de tamamla. |
| App Privacy | IN PROGRESS | BOTH | Yes | `docs/APP_PRIVACY_MATRIX_FINAL.md` repo/code/SDK envanterini içeriyor. App Store Connect ve Organizer raporu teyidi yok. | ASC cevaplarını kullanıcı girsin ve archive raporuyla satır satır doğrulasın. |
| Website | IN PROGRESS | CODEX | Yes | TR/EN hero, sticky story, app ikon/screenshot, app tokenları, vector Wave/Seigaiha, dark mode, reduced motion, 320–1440 px overflow testi ve localhost route smoke tamam. Release flagleri bilinçli açık. | Gerçek domain/legal girdilerden sonra canonical/sitemap/OG/App Store badge ve Lighthouse. |
| Privacy Policy | BLOCKED BY USER | BOTH | Yes | Kod davranışıyla denetlendi; Firebase, Crashlytics, AdMob, UMP, ATT, RevenueCat, Location, HealthKit, Photos ve kapalı Supabase davranışı açıklanıyor. Taslak uyarısı/noindex aktif. | Veri sorumlusu, adres, privacy e-postası ve hukuk incelemesi. |
| Terms | BLOCKED BY USER | BOTH | Yes | Abonelik, güvenli navigasyon ve sorumluluk taslağı mevcut; noindex aktif. | Yayıncı, uygulanacak hukuk, adres/e-posta ve insan/hukuk incelemesi. |
| Support | BLOCKED BY USER | BOTH | Yes | TR/EN troubleshooting, restore, privacy/deletion yolu mevcut. Çalışan e-posta yok. | Support e-postası sağla ve gerçek mesaj akışını test et. |
| Domain | BLOCKED BY USER | USER | Yes | Production host boş; tahmini `pinly.app` linki yok. | Marka taramasından sonra domain edin, DNS/HTTPS yapılandır ve hostu local config'e gir. |
| App Store metadata | IN PROGRESS | BOTH | Yes | `marketing/APP_STORE_METADATA_TR_EN.md` gerçek ürün kapsamına göre TR/EN taslak içeriyor. Final name, category, countries ve App Store ID yok. | ASC girdilerini sağla; limitleri ve review notes'u final kayda göre tekrar doğrula. |
| Screenshots | BLOCKED BY USER | BOTH | Yes | Yalnız gerçek TR/EN Home simulator görüntüsü var; sahte rota/nav/Live Activity UI üretilmedi. Gereksinim `docs/SCREENSHOT_REQUIREMENTS.md`. | Temiz demo verisiyle 9 ürün sahnesini üret ve kişisel veri incelemesi yap. |
| Brand/name clearance | BLOCKED BY USER | USER | Yes | Teknik marka sistemi çıkarıldı; hukuki isim uygunluğu araştırması yapılmış sayılmıyor. | App Store/Play, TÜRKPATENT, EUIPO, WIPO, gerekirse USPTO + domain/social kontrolü. |
| Physical-device QA | BLOCKED BY USER | USER | Yes | `docs/DEVICE_QA.md` kanıt şablonu hazır; fiziksel sonuç yok. | Cihaz matrisi, erişilebilirlik, export ve iki gerçek yürüyüşü aynı RC build'de tamamla. |
| TestFlight | BLOCKED BY USER | USER | Yes | Archive/upload/beta build numarası yok. | Tüm önceki blocking satırlar PASS olduktan sonra RC yükle; 5–20 gerçek kullanıcıyla test et. |

## Gate özeti

- Merge Gate: **kapalı** — PR ve yeşil CI kanıtı yok; kullanıcı/legal/device/RevenueCat girdileri eksik.
- App Store Submission Gate: **kapalı** — archive, gerçek cihaz, sandbox purchase, public legal URL, ASC privacy ve screenshot seti eksik.
- Codex hiçbir harici sistemi değiştirmedi; website yayınlanmadı, archive yüklenmedi ve branch merge edilmedi.
