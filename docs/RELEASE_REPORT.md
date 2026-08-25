# Pinly V1 — Final Release Hardening Report

> Bu belge ayrıntılı mühendislik yorumudur. Güncel gate/status için tek kaynak `docs/FINAL_RELEASE_STATUS.md`; final puan için `docs/FINAL_SCORING_AUDIT.md` kullanılır.

Tarih: 2026-08-25  
İncelenen kapsam: iOS app, extension, SwiftData modelleri, third-party SDK'lar, CI, StoreKit/RevenueCat, AdMob/UMP/ATT, analytics, privacy manifest, social V1 sınırı, TR/EN website/legal taslakları, ASO ve release süreci.

## Yönetici özeti

**Bugünkü karar: NO-GO.** Kod tabanı gönderime yakın ve teknik hardening'in büyük kısmı tamam; fakat production domain/legal kimlik, support/privacy e-postası, App Store ID, production interstitial ID, App Store/RevenueCat/AdMob dashboard doğrulamaları, gerçek cihaz/sandbox QA ve çalışan CI test sonucu olmadan App Store'a gönderilmemeli.

Bu girdiler ve `docs/RELEASE_QA_MATRIX.md` P0 suite tamamlandığında karar **conditional GO** seviyesine çıkabilir. İncelemede bilinen kritik/severe bir doğrudan kod açığı kalmadı; açık risklerin çoğu dış sistem/operasyon, privacy beyanı ve gerçek cihaz davranışıdır.

Subjektif ürün/release puanları (10 üzerinden, karşılaştırmalı kalite sinyali; sertifika değildir):

- Güvenlik ve fail-closed davranış: **8.2**
- Privacy engineering: **8.0**; legal/ASC operasyon hazır oluşu: **5.5**
- Mimari: **7.6**
- Kod kalitesi/test edilebilirlik: **7.5**
- Kullanım ve UX: **7.8**
- Monetizasyon doğruluğu: **8.4**
- Reklam politikası: **8.7**
- Website/ürün anlatımı: **8.2**; production yayın hazır oluşu: **5.0**
- Pazarda farklılaşma: **6.8**

## Bu hardening turunda kapanan başlıca riskler

### Build ve CI

- Clean checkout'un derlenmesini engelleyen gitignore/config/package state düzeltildi.
- Güvenli örnek `Config.xcconfig` izleniyor; production client değerleri ignored `Config.local.xcconfig` içinde kalıyor.
- Package lock izleniyor ve CI otomatik dependency resolution'a güvenmiyor.
- CI mevcut iPhone simulator'ı dinamik seçiyor; Debug test ve Release compile artifact üretiyor.
- Firebase/RevenueCat config yoksa app clean build'de crash etmek yerine güvenli NoOp/fail-closed çalışıyor.
- Dependabot Swift package güncellemeleri haftalık tanımlandı.

### Ürün gerçeği ve monetizasyon

- Free artık her yerde aynı: sınırsız mekan + çekirdek rota/navigasyon + kontrollü reklam.
- Pro: GPX/PDF export + reklamsızlık. Olmayan offline map, social veya “unlimited Pro” vaadi kaldırıldı.
- Fiyat yalnız StoreKit/RevenueCat localized değerinden geliyor; website/metadata sabit fiyat vaat etmiyor.
- Trial yalnız RevenueCat açıkça `.eligible` dediğinde görünür.
- Purchase/restore sadece aktif `pro` entitlement ile başarı sayılır.
- Export paywall satın alımından sonra bekleyen GPX/PDF işlemi otomatik devam eder.
- Interstitial 7 dakika ve 2/session ile sınırlı; navigation start ve paylaşım önünde reklam yok; Pro'da sıfır reklam.

### Privacy ve reklam güvenliği

- Privacy manifest SDK davranışıyla uyumlu ihtiyatlı hale getirildi; yalnız cihazda kalan precise location/Health “collected” olarak yanlış beyan edilmiyor.
- UserDefaults required-reason `CA92.1` doğrulandı.
- UMP/ATT onboarding/profil tamamlanmadan başlamıyor.
- Bilinen 16 yaş altı under-age, 13 yaş altı child-directed; bu kullanıcılara ATT sorulmuyor.
- Privacy Choices ekranı UMP seçeneklerini yeniden açıyor ve iOS Settings/legal/support yollarını sunuyor.
- Gereksiz Health write usage metni kaldırıldı; uygulama HealthKit'e yazmıyor.
- Konum izni ertelenebilir; ret/skip artık tüm uygulamayı kilitlemiyor.
- Profil ekranı verinin yalnız cihazda kaldığını ve hesap oluşmadığını açıkça söylüyor.

### Güvensiz girdiler

- QR/deep link scheme/host, payload ve koordinat doğrulaması var.
- Tek mekan URL 16 KB; rota payload 64 KB; rota 50 durak; Swarm dosyası 10 MB ve 500 kayıtla sınırlı.
- İsim/kategori/adres/not alanları uzunluk sınırına sahip; bir bozuk durak sessizce düşürülmeyip rota reddediliyor.
- PDF/GPX dosya adı sanitize; GPX XML içeriği escaped.
- Production interstitial unit ID kaynak koddan çıkarıldı; config + preflight kontrolüne taşındı.

### Social V1

- Social/community/shared-route/Apple login V1 navigasyonundan çıkarıldı.
- Tek `SocialFeaturePolicy` NoOp servis çözüyor; okumalar boş, mutasyonlar sahte başarı yerine `disabled` hatası veriyor.
- V1 normal kullanımında Supabase oturumu veya veri yazımı yok.
- Account yaratılmadığı için eksik account deletion akışı App Review kapsamına girmiyor.

## Güvenlik değerlendirmesi

### Güçlü taraflar

- Swift'in memory-safe varsayımları, SwiftData ve sistem picker/StoreKit/MapKit kullanımı klasik web injection yüzeyini azaltıyor.
- Dependency ve service composition çoğunlukla protokol üzerinden; kritik kararlar saf ve test edilebilir politikalara ayrılmış.
- Üretim config eksikliği sessizce canlı servise yanlış bağlanmak yerine release preflight'ı fail ediyor.
- Analytics event setinde ad, not, fotoğraf veya kesin koordinat parametresi yok.
- Background konum yalnız navigasyonda açılıyor; stop/complete ve 2 saat timeout ile kapanıyor.

### Kalan riskler

1. **Production dashboard drift:** AdMob/Firebase/RevenueCat ayarları repo dışıdır; privacy/entitlement davranışını değiştirebilir. İkinci kişi kontrolü ve ekran görüntülü release evidence şart.
2. **SDK attack surface:** Social V1 kapalı olsa da Supabase kodu ve dependency'si target içinde derleniyor. V1.1 ertelenecekse live sosyal kaynaklarını ayrı target/package veya compile flag ile binary'den tamamen çıkarmak iyi bir sonraki adımdır.
3. **Local-only data loss:** App uninstall cihazdaki mekan/fotoğraf/rota geçmişini siler; sync/backup yok. Bu güvenlikten çok kullanıcı güveni ve retention riskidir; UI/support açıkça söylemeli.
4. **No dedicated SAST/SCA gate:** Dependabot eklendi fakat CI'da secret scanner, license inventory veya advisory fail gate yok. GitHub secret scanning/CodeQL imkânı varsa etkinleştirilmeli.
5. **Simulator evidence gap:** Test bundle derleniyor ama bu makinedeki runner test host'u başlatamıyor. CI green olmadan release yok.
6. **Dormant social config:** `SocialConfig` live kodda precondition kullanıyor; V1 policy bu yola erişimi kesiyor. V1.1'de precondition yerine typed configuration error tercih edilmeli.

## Mimari ve kod kalitesi

Yaklaşık 121 app Swift dosyası / 20.4K satır ve 48 test dosyası / 3.3K satır var. Composition root `PinlyApp`, environment protocol'leri, ViewModel'ler, repository/service ayrımı ve saf policy testleri ölçeğe göre iyi. Runtime analytics router, entitlement source-of-truth ve social hard-off kararlarının tek noktada toplanması doğru mimari hamleler.

En önemli borç UI dosya büyüklüğü: `RouteSummaryView` 850+, `DiscoverView` 750+, `ProfileTab` 540+, `PaywallView` 480+ satır. Bu dosyalar feature section/subview ve state reducer'lara bölünmezse regresyon maliyeti artar. `SharedRouteEditorView` kapalı V1 özelliği olduğu halde yaklaşık 490 satır ve SDK bağımlılıklarıyla ana target'ta kalıyor.

Singleton sayısı yüksek; protokol enjeksiyonu bunu kısmen dengeliyor. Yeni geliştirmede stateful `.shared` bağımlılığı doğrudan ViewModel default'una eklenmemeli; composition root veya mevcut runtime router deseni kullanılmalı.

Kodda guard ile güvenli oldukları halde kalan force unwrap'lar temizlendi. TODO/FIXME bulunmaması iyi görünse de risk kaydı docs/checklist'te tutulmalı; “yorum yok = borç yok” sayılmamalı.

## Kullanıcı deneyimi

### Güçlü taraflar

- “Kaydet → rotala → yürü → anılaştır” tek ve anlatılabilir ana döngü.
- Hazır şehir rotaları cold-start problemini azaltıyor.
- Location/profile artık ertelenebilir; gereksiz izinler değer anında isteniyor.
- Gerçek app screenshot'lı website ürün beklentisini daha doğru kuruyor.
- Link/QR import ve memory card paylaşımı hesapsız viral döngü sağlayabilir.
- Free mekan limitinin kaldırılması erken kullanıcıda yapay paywall sürtünmesini azaltıyor.

### Zayıf taraflar ve önerilen sıra

1. İlk oturumda onboarding + profil + location + UMP/ATT sıralı yükü hâlâ ağır olabilir. Profil skip oranı ve ilk rota süresi ölçülmeli; profile completion ilk değer sonrasına ertelenebilir.
2. Kullanıcı lokasyon/Health/photo izinlerini reddettiğinde her özellikte güçlü empty/error state gerçek cihazda doğrulanmalı.
3. App yalnız light mode'a zorlanıyor. V1 için dürüst bir kapsam kararı; ancak sistem dark mode kullanıcılarında kalite algısını düşürür.
4. iCloud/sync/backup olmaması “kaydedilmiş mekanlarım kalıcı” beklentisiyle çatışabilir.
5. Büyük SwiftUI ekranlarında state ve sheet/cover zinciri karmaşık; UI automation olmadan regressions olası.
6. Accessibility manuel kanıt yok: Dynamic Type XXL, VoiceOver rotor/focus, reduce motion ve contrast P0 QA'ya dahil edildi.

## Pazar ve tutma olasılığı

Pinly'nin problemi gerçek: farklı yerlerde biriken “gidilecek yerler” listesini yürünebilir güne çevirmek. Ancak kategori güçlü yerleşik ve bağımsız rakiplere sahip. Apple Maps artık yer/not/guide kaydetme, paylaşma ve özel yürüyüş rotaları sunuyor; bazı bölgelerde offline rota da var. Wanderlog ücretsiz sınırsız durak, itinerary, collaboration ve offline planlarla; Mapstr ise güçlü saved-place/tag/share ağıyla rekabet ediyor. Bu nedenle “yer kaydetme + harita” tek başına savunulabilir farklılık değil.

Savunulabilir wedge şudur: **Türkiye/turist şehirlerinde hazır yürüyüş günü + birkaç kaydı tek dokunuşla yürünebilir sıraya çevirme + rota sonunda kişisel anı kartı.** Pazarlama bu üçüne daralmalı. Badges ve PDF/GPX destekleyici özelliklerdir; ana satın alma sebebi olmayabilir.

Prelaunch durumda güvenilir başarı yüzdesi hesaplanamaz. Aşağıdaki bantlar istatistik değil, mevcut ürün/rekabet/dağıtım durumuna dayalı karar tahminidir:

- Production girdileri ve QA tamamlanırsa ilk App Review'u teknik olarak geçme olasılığı: **yüksek, yaklaşık %70–85**. Ana belirsizlik background location/HealthKit/privacy metadata ve subscription review.
- Organik olarak anlamlı ilk çekiş sinyali (örneğin tek bir şehir segmentinde 1.000 MAU ve D30 ≥ %8) alma olasılığı: odaksız genel “travel app” lansmanında **düşük (%10–20)**; İstanbul yürüyüş günü gibi dar içerik/creator dağıtımı ve haftalık iterasyonla **orta (%25–40)**.
- 12 ay içinde sürdürülebilir indie gelir üretme olasılığı prelaunch verisiyle **düşük-orta (%15–30)**. GPX/PDF + ad-free tek başına güçlü subscription value olmayabilir; gerçek satın alma verisi gelmeden yeni Pro vaat eklenmemeli.

Bu tahminleri geçersiz kılacak en önemli veri kohort retention'dır. İlk 500–1.000 nitelikli kullanıcıda şu eşikler izlenmeli:

- Onboarding → ilk mekan veya hazır rota kabulü: hedef ≥ %55.
- İlk oturumda route start: ≥ %35.
- Başlayan rotada completion: ≥ %45.
- D7 retained: ≥ %15; D30: ≥ %8.
- Route completion başına paylaşım: ≥ %8.
- Paywall view → verified purchase/trial: storefront ve trafik kalitesine göre izlenir; trial uygunluk ayrımı yapılmadan tek oran yorumlanmaz.

İki ardışık nitelikli kohort hedeflerin ciddi altında kalırsa reklam veya social eklemek yerine activation/route reliability düzeltilmeli.

## Reklam politikası yorumu

Mevcut politika erken ürün için ölçülü: navigation start'ta reklam yok, paylaşım önü kaldırıldı, yalnız rota bitişindeki doğal geçişte; 7 dakika minimum ve 2/session tavanı; Pro'da sıfır. Bu, gelirden önce retention'ı korur.

Yine de rota completion kullanıcı ödül anıdır. Deney sonucu completion overlay öncesi reklam completion-to-memory/share oranını düşürürse interstitial overlay sonrasına veya ikinci tamamlanan rotadan sonrasına taşınmalı. İlk rota tamamlamada reklam göstermemek güçlü bir A/B adayıdır. eCPM yerine “reklam gören kohort D1/D7 ve ikinci rota” metriği karar versin.

Yaşı bilinmeyen kullanıcı mixed-audience belirsizliği ve Google dashboard ayarları hukukça onaylanmalı. AdMob politikası, uygulama privacy policy'sinde Google kaynaklı collection/sharing ve gerekli consent açıklamasını şart koşar; website taslağı bunu içerir ama gerçek veri sorumlusu/iletişim eklenmeden yayınlanmaz.

## Website ve legal

Website TR/EN responsive, gerçek screenshot kullanıyor ve ürün gerçeğiyle hizalı. Privacy, terms, support ve privacy choices rotaları var. Sabit fiyat, 20-place limiti, offline map ve doğrulanmamış domain iddiası temizlendi.

Legal metinler bilinçli taslaktır, hukuk görüşü değildir. `SITE_REQUIRED_INPUTS.md` tamamlanana kadar `data-release-ready=false`, `noindex,nofollow` ve draft uyarıları release'i bloklamalı. Uygulama legal URL'leri boş/yanlış hostta nil döner; böylece başka ürüne ait sayfayı göstermez.

## Doğrulama kaydı

Build notu: Aşağıdaki Debug/Release build sonuçları `5e94876` baseline'ında alındı. Sonraki RC çalışma ağacında değişen Swift dosyaları parse edildi; güncel compile/test kanıtı sandbox SwiftPM/CoreSimulator kısıtı nedeniyle PR CI'a bağlıdır.

Geçenler:

- `plutil` — Info.plist, entitlements, privacy manifest, project file.
- `swiftc -frontend -parse` — değiştirilen Swift/test kaynakları.
- `git diff --check`.
- Baseline iPhone 16 Pro / iOS 18.6 Debug `build-for-testing`: **SUCCEEDED**.
- Baseline clean Release simulator compile: **SUCCEEDED** (iPhone 16 Pro / iOS 18.6).
- Clean `.app` paket taraması: geliştirme ayarı `Pinly/.claude/settings.local.json` target üyeliğinden çıkarıldı ve pakette bulunmadığı doğrulandı.
- Website 10 rota/assets local HTTP 200; desktop ve 390 px mobile browser smoke.

Geçmeyen/bloklu:

- Bu hosttaki CoreSimulator app test runner başlamadığı için unit test execution sonucu yok.
- `scripts/release_preflight.sh` production website host, App Store ID, production ad unit ve final legal sayfaları beklediği için bilinçli FAIL.
- Archive/signing, sandbox purchase, gerçek cihaz permission/background/location/HealthKit/ads ve App Store validation yapılmadı.

## Önerilen sonraki sıra

1. `SITE_REQUIRED_INPUTS.md` verilerini ve hukuk onayını tamamla.
2. Production domain'i yayınla; config host/App Store/ad unit değerlerini ignored local config'e gir.
3. GitHub CI'da tüm unit testleri çalıştır; yeşil artifact olmadan ilerleme.
4. Gerçek cihaz + sandbox P0 QA ve privacy network capture.
5. Archive privacy report/Validate App; ASC privacy answers ve review notes ikinci kişi kontrolü.
6. Küçük TestFlight kohortu; activation, route completion, D1/D7 ve reklam etkisini ölç.
7. Ancak bu veriden sonra phased App Store release.

## Resmi kaynaklar

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Apple auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- [Firebase privacy and security](https://firebase.google.com/support/privacy)
- [Google Mobile Ads iOS targeting/age treatment](https://developers.google.com/admob/ios/targeting)
- [Google advertising technology policy](https://policies.google.com/technologies/ads)
- [RevenueCat privacy policy](https://www.revenuecat.com/privacy-policy)
- [Apple Maps saved/custom walks](https://support.apple.com/en-gb/guide/iphone/iph3d7ebd491/ios)
- [Wanderlog App Store listing](https://apps.apple.com/tr/app/wanderlog-travel-planner/id1476732439)
- [Mapstr App Store listing](https://apps.apple.com/us/app/mapstr-save-follow-places/id917288465)
