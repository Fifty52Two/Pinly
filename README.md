# Pinly

Mekan kaydetme + yürüyüş rotası planlama + turn-by-turn navigasyon uygulaması. iOS için SwiftUI ile yazılmıştır (eski adı NotionGO).

Foursquare City Guide Aralık 2024'te kapandı; Türkiye o platformun global trafiğinin yaklaşık %9'unu oluşturuyordu. Pinly bu boşluğu doldurmak için Türkiye ve turist kullanıcılar odağında geliştiriliyor.

## Öne Çıkan Özellikler

- Mekan kaydetme: adres arayarak, mevcut konumla veya haritada pinleyerek; fotoğraf ekleme
- İki farklı rota oluşturma akışı: anlık (kategori seçip mekan öner) ve önceden planlama
- Turn-by-turn yürüyüş navigasyonu, rota sapması algılama, kilit ekranı Live Activity + Dynamic Island
- Kayıtlı rotalar, rota geçmişi, haftalık rapor, profil istatistikleri
- 21 rozetlik ödül sistemi
- Paylaşım: QR kod, rota linki, GPX/PDF export, Instagram paylaşım kartı, Swarm (Foursquare) import
- Yakınımda önerileri ve Keşfet haritası
- 5 dil desteği (Türkçe, İngilizce, İspanyolca, Almanca, Rusça), uygulama içinden değiştirilebilir
- Freemium model (20 mekan ücretsiz limiti) + Ana ekran hızlı ekle widget'ı

## Teknik Stack

- SwiftUI + SwiftData (iOS 17+)
- MapKit (yürüyüş rotası hesaplama ve harita gösterimi)
- ActivityKit (Live Activity), WidgetKit
- HealthKit (adım/mesafe), AVFoundation (QR tarama), CoreImage (QR üretme)
- Firebase (Crashlytics + Analytics), GoogleMobileAds
- MVVM + protokol tabanlı servis katmanı mimarisi

## Gereksinimler

- Xcode 16+
- iOS 17+ hedef cihaz veya simülatör

## Kurulum ve Çalıştırma

```bash
# Simülatörde derle
xcodebuild -scheme Pinly -destination 'platform=iOS Simulator,name=iPhone 16' build

# Tüm testleri çalıştır
xcodebuild -scheme Pinly -destination 'platform=iOS Simulator,name=iPhone 16' test
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
```

Mimarinin ve her dosyanın detaylı açıklaması için `CLAUDE.md`'ye bakın.

## Proje Durumu

Uygulama şu an TestFlight beta aşamasında. Güncel yol haritası ve ilerleme durumu için `RELEASE_PLAN.md` dosyasına bakın.

## Lisans

Bu proje için henüz bir lisans belirlenmedi.
