# Pinly V1 App Privacy Matrix

> **SUPERSEDED:** Submission için `docs/APP_PRIVACY_MATRIX_FINAL.md` kullanılır. Bu dosya önceki ayrıntılı audit anlatımı olarak korunur; App Store Connect cevabının tek kaynağı değildir.

Durum: kod ve paket manifestleri incelendi; App Store Connect ve sağlayıcı dashboard teyidi bekliyor.  
Son doğrulama: 2026-08-25

## Temel ayrım

Apple'ın tanımında “toplama”, verinin cihaz dışına gönderilip isteği gerçek zamanda karşılamak için gerekenden daha uzun süre geliştirici veya üçüncü tarafça erişilebilir tutulmasıdır. Bu nedenle SwiftData/UserDefaults/Documents içinde kalan profil, fotoğraf, kesin konum, rota ve HealthKit sonuçları App Store privacy label açısından “collected” değildir. MapKit/StoreKit gibi Apple servislerinin Apple tarafından topladığı veriyi geliştirici ayrıca beyan etmez.

Uygulama manifesti `Pinly/PrivacyInfo.xcprivacy`, uygulamanın doğrudan kullanımını ve gömülü SDK'ların en geniş üretim davranışını ihtiyatlı biçimde beyan eder. SDK manifestleri archive içinde ayrıca birleşir.

## Veri envanteri

| Veri | Kaynak / saklama | Cihaz dışına çıkar mı? | Amaç | Linked / tracking | App Store Connect önerisi |
|---|---|---|---|---|---|
| Ad, soyad, doğum yılı | Kullanıcı; UserDefaults | V1 normal akışında hayır | Yerel profil | Hayır / hayır | Toplanmıyor. V1.1 profil senkronu açılırsa yeniden değerlendir. |
| Profil ve mekan fotoğrafları | PhotosPicker/kamera; Documents | Yalnız kullanıcı share sheet ile bilerek paylaşır | App functionality | Hayır / hayır | Toplanmıyor; destek formuna gönderim ayrı ve isteğe bağlı olabilir. |
| Kesin konum ve rota izi | CoreLocation/SwiftData | Pinly/Firebase/RevenueCat/AdMob'a doğrudan gönderilmez; Apple MapKit istekleri servis için kullanılır | Navigasyon | Hayır / hayır | Precise Location: “not collected by developer”. Permission metni ve privacy policy'de cihaz içi kullanım açıklanır. |
| HealthKit adım/mesafe | HealthKit; rota geçmişinde yerel agregat | Hayır | Rota özeti | Hayır / hayır | Health/Fitness: “not collected”. Reklam/analytics parametresine kesinlikle eklenmez. |
| Mekan adı, adres, not, rota | SwiftData; link/QR ile kullanıcı paylaşımı | Otomatik backend yok; paylaşım yalnız kullanıcı eylemi | App functionality | Hayır / hayır | Other User Content: otomatik toplanmıyor. Sosyal V1.1 açılırsa yeniden beyan zorunlu. |
| Ürün etkileşimi | Firebase Analytics ve AdMob | Evet | Analytics / third-party advertising | AdMob manifestinde linked; tracking false | Product Interaction: collected, linked to identity/device; Analytics + Third-Party Advertising. |
| Device ID | Firebase installation/Crashlytics IDs; AdMob IDFV/izin varsa IDFA | Evet | Analytics / ads | AdMob'a göre linked; IDFA tracking true | Device ID: collected, linked, used for tracking ve Third-Party Advertising + Analytics. ATT reddinde IDFA yolu kapalı olsa da en geniş davranış beyan edilir. |
| Yaklaşık konum | AdMob/UMP tarafından IP gibi sinyallerden çıkarılabilir | Evet | Ads / analytics / consent | AdMob manifestinde linked; tracking false | Coarse Location: collected, linked; Third-Party Advertising + Analytics. GPS kesin konum reklam isteğine eklenmez. |
| Reklam verisi | AdMob | Evet | Reklam sunumu/ölçüm | SDK manifestinde linked; tracking false | Advertising Data: collected, linked; Third-Party Advertising + Analytics. |
| Satın alma geçmişi | StoreKit/RevenueCat | Evet | Entitlement ve restore | RevenueCat manifestinde linked false; tracking false | Purchase History: collected, not linked, App Functionality. Dashboard user-ID ayarı değişirse linked cevabını güncelle. |
| Crash ve diğer tanılama | Firebase Crashlytics | Evet | Hata ayıklama / stabilite | SDK manifestinde not linked; not tracking | Crash Data + Other Diagnostic Data: collected, not linked, App Functionality. |
| Performans verisi | AdMob SDK; MetricKit özetleri ayrıca cihazda | AdMob kısmı evet | Ads / analytics | SDK manifestinde not linked; not tracking | Performance Data: collected, not linked; Analytics + Third-Party Advertising. |
| Destek mesajı | Gelecekte e-posta/destek kanalı | Kullanıcı bilerek gönderirse | Customer support | İçeriğe göre değişir | İsteğe bağlı ve seyrek destek iletimi Apple'ın optional disclosure şartlarıyla hukukça teyit edilmeli. |

## İzin ve yaşam döngüsü

- Konum izni onboarding sonrasında, özelliğin değeri görüldüğünde istenir. Navigasyon başladığında background update açılır; bitişte veya 2 saat sonra kapanır.
- Kamera yalnız QR tarama veya fotoğraf çekme eyleminde kullanılır. PhotosPicker sistem seçicisidir.
- HealthKit izni rota özeti özelliğinden kullanıcı eylemiyle istenir; yalnız read types kullanılır. Bu nedenle gereksiz `NSHealthUpdateUsageDescription` kaldırıldı.
- Bildirim izni haftalık rapor CTA'sından istenir; onboarding'de istenmez.
- UMP/ATT onboarding ve profil adımı tamamlanmadan açılmaz. Bilinen 16 yaş altı UMP under-age olarak işaretlenir, 13 yaş altı child-directed reklam alır; iki grup için ATT istenmez. Yaşı bilinmeyen kullanıcı için hukuki/minimum-age kararı release girdisidir.
- UMP `canRequestAds` true olmadan Mobile Ads başlatılmaz. Kullanıcı Profil → Gizlilik Tercihleri'nden privacy options formunu tekrar açabilir.

## Required-reason API

Uygulama kodunun kapsanan tek doğrudan API kategorisi `UserDefaults` olup app-container içi tercihler için Apple onaylı `CA92.1` nedeni bildirilmiştir. File timestamp, disk space, system boot time ve active keyboard required-reason API'leri uygulama kaynaklarında kullanılmıyor. Gömülü SDK'lar kendi manifestlerinde kullandıkları kategorileri ayrı bildirir.

## Yayın öncesi zorunlu teyitler

1. Xcode Organizer archive privacy report'u dışa aktar; bu matrisi birleşik raporla satır satır karşılaştır.
2. App Store Connect privacy answers'ı bu belgenin “en geniş davranış” sütununa göre doldur.
3. AdMob'da EEA/UK/CH, US states, IDFA mesajı, child/teen treatment, mediation ve data-sharing ayarlarını doğrula.
4. Firebase Analytics advertising personalization / Google Signals / ads link ayarlarını ve retention'ı doğrula.
5. RevenueCat'te custom App User ID gönderilmediğini; anonim kimliğin kişisel profille birleştirilmediğini doğrula.
6. Gerçek cihaz proxy/network kaydıyla kesin konum, HealthKit, ad/soyad, doğum yılı, not veya fotoğrafın Google/RevenueCat'e gitmediğini kontrol et.
7. Hukuk danışmanı; minimum yaş, çocuklara yönelik olup olmama, KVKK/GDPR veri sorumlusu ve saklama metnini onaylamadan legal sayfalardaki draft işaretlerini kaldırma.

## Kanıt noktaları

- `Pinly/PrivacyInfo.xcprivacy`
- `Pinly/Services/ConsentManager.swift`
- `Pinly/Services/HealthKitService.swift`
- `Pinly/Managers/LocationManager.swift`
- `Pinly/Services/ProfileService.swift`
- `Pinly/Services/AnalyticsService.swift`
- `Pinly/Managers/AdManager.swift`
- `Pinly/Services/PurchasesService.swift`
- `docs/SOCIAL_V1_AUDIT.md`

Bu belge hukuki görüş değildir; kod ve paket davranışına dayalı release mühendisliği kaydıdır.
