# Pinly

Mekan kaydetme + yürüyüş rotası planlama + turn-by-turn navigasyon uygulaması. iOS için SwiftUI ile yazılmıştır (eski adı NotionGO).

Foursquare City Guide'ın kapanmasının ardından Pinly, kaydedilmiş mekanları yürünebilir rotalara dönüştürmek isteyen kullanıcılar için Türkiye ve şehir gezisi odağında geliştiriliyor.

## Öne Çıkan Özellikler

- Mekan kaydetme: adres arayarak, mevcut konumla veya haritada pinleyerek; fotoğraf ekleme
- İki farklı rota oluşturma akışı: anlık (kategori seçip mekan öner) ve önceden planlama
- Turn-by-turn yürüyüş navigasyonu, rota sapması algılama, kilit ekranı Live Activity + Dynamic Island
- Kayıtlı rotalar, rota geçmişi, haftalık rapor, profil istatistikleri
- 21 rozetlik ödül sistemi
- Paylaşım: QR kod, rota linki, Instagram paylaşım kartı
- Yakınımda önerileri ve Keşfet haritası
- 5 dil desteği (Türkçe, İngilizce, İspanyolca, Almanca, Rusça), uygulama içinden değiştirilebilir
- Ana ekran hızlı ekle widget'ı
- Freemium: mekan kaydetme ücretsiz ve **sınırsız**; Pinly Pro (abonelik) reklamsız kullanım
  ile GPX ve PDF dışa aktarma sağlar

## Teknik Stack

- SwiftUI + SwiftData (iOS 17+)
- MapKit (yürüyüş rotası hesaplama ve harita gösterimi)
- ActivityKit (Live Activity), WidgetKit
- HealthKit (adım/mesafe), AVFoundation (QR tarama), CoreImage (QR üretme)
- RevenueCat (abonelik), GoogleMobileAds + UMP consent + App Tracking Transparency
- Firebase (Crashlytics + Analytics)
- Supabase (sosyal katman — V1'de kapalı, bkz. Proje Durumu)
- MVVM + protokol tabanlı servis katmanı mimarisi

## Gereksinimler

- Xcode 16+
- iOS 17+ hedef cihaz veya simülatör

## Kurulum ve Çalıştırma

Repo güvenli clean-checkout varsayılanlarıyla derlenir. RevenueCat, Supabase ve production
AdMob istemci değerleri için `Config.local.example.xcconfig` dosyasını
`Config.local.xcconfig` adıyla kopyalayıp doldurun. Firebase Analytics/Crashlytics için
Firebase Console'dan indirilen `GoogleService-Info.plist` dosyasını `Pinly/` altına koyun.
Bu iki yerel dosya Git tarafından izlenmez; server-only/service-role secret'ları iOS
uygulamasına eklemeyin.

```bash
# Simülatörde derle
xcodebuild -project Pinly.xcodeproj -scheme Pinly \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Tüm testleri çalıştır
xcodebuild -project Pinly.xcodeproj -scheme Pinly \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

Ya da `Pinly.xcodeproj` dosyasını Xcode'da açıp normal şekilde çalıştırabilirsiniz.

## Proje Yapısı

```
Pinly/
  Managers/    ObservableObject state yöneticileri (RouteManager, PlaceStore, LocationManager, ...)
  Models/      SwiftData modelleri ve veri yapıları (Place, SavedRoute, RouteHistory, ...)
  Services/    Protokol tabanlı servisler (entitlements, badges, ads, geocoding, ...)
  ViewModels/  Ekranlara özel iş mantığı
  Views/       SwiftUI ekranları
  Design/      Tasarım sistemi (Theme.swift)
PinlyTests/    Unit testler
content/       Hazır başlangıç rotaları (şehir bazlı JSON katalog)
specs/         Faz bazlı tasarım kararları
docs/archive/  Tamamlanmış plan belgeleri (tarihsel — güncel durumu tarif etmez)
```

Güncel çalışma kuralları için `AGENTS.md`'ye bakın. `docs/archive/` altındaki planlar tarihsel kayıttır ve production davranışının kaynağı değildir.

## Proje Durumu

Uygulama V1 release-candidate hazırlığındadır; bu repoda doğrulanmış bir TestFlight build'i henüz yoktur.
V1 release hazırlığı production kodu, testler ve `docs/` altındaki güncel checklist'lerle takip edilir; eski büyüme ve release planları kaynak gerçekliği değildir.
Tek karar kaynağı `docs/FINAL_RELEASE_STATUS.md` dosyasıdır.

**Sosyal katman (topluluk rotaları, rota yayınlama, Apple ile giriş) V1'de kapalıdır.**
Kod yerinde duruyor ama arayüzden erişilemez. V1.1'de açılmadan önce şunlar tamamlanmalı:
uygulama içi hesap silme (App Store Guideline 5.1.1(v)), yayınlanan rota içeriğinin
kullanıcı notlarından arındırılması, engellemenin sunucu tarafında gerçekten uygulanması
ve anonim → Apple hesap geçişinde veri taşıma.

## Lisans

Bu proje için henüz bir lisans belirlenmedi.
