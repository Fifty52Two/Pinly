# Pinly V1 — Security Final Sweep

Son güncelleme: 25 Ağustos 2026. Kapsam: tracked kaynak kodu, build config, plist/entitlements/privacy manifest, CI ve V1'de erişilebilen çalışma zamanı yolları.

## Sonuç

Repo/code status: **PASS** — `scripts/security_sweep.sh`, plist lint ve insan incelemesi tamamlandı. External dashboard, dependency alert ekranı ve final archive kontrolleri ayrı release blocker'larıdır.

- Tracked production secret bulunmadı. `Config.local.xcconfig` ignore ediliyor; repoda yalnız boş anahtarlar ve örnek dosya var.
- Supabase `service_role`, admin anahtarı, özel anahtar bloğu, hard-coded Bearer token, GitHub token veya App Store Connect `.p8` içeriği bulunmadı.
- Google Ads App ID/ad-unit ID gizli veri değildir; yine de production değerleri tracked dosyaya yazılmıyor.
- RevenueCat public SDK key'i secret değildir; production değeri tracked dosyada değil, local config üzerinden sağlanıyor.
- Apple identity token loglanmıyor veya yerel dosyaya kaydedilmiyor. V1 social composition root'u NoOp servislerine kilitli.
- Debug analytics payload çıktıları yalnız `#if DEBUG` içinde; release analytics allowlist ile sınırlı.
- Force unwrap/fatal crash yolu taramasında uygulama runtime'ında yeni kritik bulgu çıkmadı. Asset üretim scriptindeki `fatalError` release binary'sine girmez.
- Best-effort `try?` kullanımları fotoğraf/cache/yardımcı kayıt yollarında mevcut. Bunlar sessiz hata görünürlüğü için V1 sonrası teknik borçtur; güvenlik veya veri sızıntısı bulgusu değildir.
- ATS istisnası, keychain access group genişletmesi veya gereksiz production entitlement bulunmadı.
- Privacy manifest ile analytics/ads/location/health/photos/RevenueCat/Firebase envanteri `APP_PRIVACY_MATRIX_FINAL.md` içinde eşlendi.
- Lockfile Google Mobile Ads SDK 13.2.0 kullanır; bu sürümde `tagForChildDirectedTreatment`/`tagForUnderAgeOfConsent` desteklenen API'dir. Google 13.3.0'da `ageRestrictedTreatment` geçişini başlattı, 13.4.0 ise minimum Xcode 26.2 ister. Dependabot Ads SDK PR'ı toolchain yükseltmesi + cihaz consent testi olmadan otomatik merge edilmemelidir.

## Tekrarlanabilir kontroller

```sh
git ls-files | rg -i '(\.p8$|\.p12$|\.mobileprovision$|id_rsa|id_ed25519|private.*key|credentials|secrets?)'
git grep -nEi 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|service[_-]?role[[:space:]]*[=:]|github_pat_|gh[pousr]_|Bearer[[:space:]]+eyJ|sk_live_'
rg -n 'NSAllowsArbitraryLoads|com\.apple\.security\.application-groups|keychain-access-groups' Pinly Pinly.xcodeproj
```

İlk iki komutun final RC'de sonuç döndürmemesi beklenir. Üçüncü komut yalnız bilinçli entitlement/ATS beyanı varsa insan incelemesine gitmelidir.

## Açık kapılar

- **BLOCKED BY USER:** GitHub branch protection, secret scanning/Dependabot alert ekranı ve CI sonuç linkleri repo yetkili görünümünden doğrulanmalı.
- **BLOCKED BY USER:** Xcode Organizer archive privacy report'u matrix ile karşılaştırılmalı.
- **BLOCKED BY USER:** App Store Connect, RevenueCat, AdMob, Firebase ve Supabase dashboard rollerinde en az ayrıcalık ve MFA doğrulanmalı.
- **BLOCKED BY USER:** Gerçek domain için HTTPS, HSTS ve güvenlik header'ları deployment sonrasında tekrar taranmalı.

SDK geçiş kaydı: [Google Mobile Ads iOS release notes](https://developers.google.com/admob/ios/rel-notes).

Bu belge pentest veya hukuk görüşü değildir; V1 release gate için repo-temelli güvenlik kanıtıdır.
