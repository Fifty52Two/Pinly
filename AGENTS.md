# Pinly Repository Instructions

Bu dosya yalnızca güncel ve operasyonel proje kurallarını içerir. Ürün davranışında kaynak gerçekliği sırası:

1. production Swift kodu
2. testler
3. build configuration
4. güncel SDK/App Store davranışı
5. README ve aktif dokümantasyon
6. `docs/archive/` ve eski plan belgeleri

Eski planlardaki fiyat, limit, tamamlanma veya root-cause iddialarını doğrulamadan kullanma.

## Ürün modeli — V1

### Free

- Mekan kaydetme ücretsiz ve sınırsızdır.
- Rota oluşturma ve yürüyüş navigasyonu kullanılabilir.
- Temel uygulama özellikleri kullanılabilir.
- Kontrollü interstitial reklam gösterilebilir.

### Pinly Pro

- Reklamsız kullanım
- GPX dışa aktarma
- PDF dışa aktarma

Pro değeri olarak 20 mekan limiti, sınırsız mekan, offline harita, community veya henüz production'da bulunmayan özellikleri kullanma. Website üzerinde App Store fiyatını hardcode etme.

## V1 sosyal katman

- Community feed, public profile, route publishing, favorite/report/block ve shared-route editing V1 kullanıcı akışında kapalıdır.
- Supabase/social kodu V1.1 için repoda kalabilir.
- V1 Release composition root'u `NoOpSocialService` ve `NoOpSharedRouteService` kullanmalıdır.
- Normal V1 akışı Supabase anonymous veya Apple-linked account oluşturmamalı; public route/social write üretmemelidir.
- Sosyal katman yeniden açılmadan önce hesap silme, public DTO sanitization, server-side RLS/rate limit/block enforcement ve anonymous→Apple veri taşıma tamamlanmalıdır.

## Mimari

- SwiftUI + SwiftData, iOS 17+
- MapKit, ActivityKit, WidgetKit, HealthKit, AVFoundation
- Firebase Analytics + Crashlytics
- RevenueCat
- Google Mobile Ads + UMP + ATT
- Supabase social infrastructure — V1 runtime'da kapalı
- MVVM + protokol tabanlı dependency injection
- Composition root: `Pinly/PinlyApp.swift`

Concrete servisleri mümkün olduğunca composition root'ta kur ve SwiftUI environment/protokoller üzerinden dağıt. ViewModel varsayılanları preview/test kolaylığı içindir; production view oluşturma noktaları gerçek environment dependency'lerini açıkça geçmelidir.

## Güvenlik ve gizlilik kuralları

- Private place notes, local identifiers ve precise coordinates açık onay olmadan public API payload'ına gönderilmez.
- HealthKit değerleri analytics, crash log veya genel loglara yazılmaz.
- Auth token/session değerleri loglanmaz.
- Service-role/admin secret veya server-only key client'a eklenmez.
- Production Supabase verisi silinmez ve production migration otomatik çalıştırılmaz.
- Pro kullanıcıya interstitial gösterilmez.
- Navigasyon başlatılırken veya aktif navigasyon sırasında interstitial gösterilmez.
- V1 social akışı backend account/write üretmez.
- Legal/privacy URL'leri HTTPS olmalı, tek kaynaktan gelmeli ve Release'te placeholder/başka ürüne ait domain olmamalıdır.

## Monetizasyon kuralları

- Release/TestFlight entitlement gerçeğinin kaynağı RevenueCat'tir.
- Debug'da `LocalEntitlementService` kullanılabilir.
- Mekan ekleme her kullanıcı için sınırsızdır.
- Free kullanıcı GPX/PDF isteğinde paywall görür; Pro kullanıcı export'a doğrudan ulaşır.
- Purchase/restore sonrası entitlement aynı akışta yenilenmeli; kullanıcı ikinci kez paywall'a düşmemelidir.
- Reklam politikası: gösterimler arasında en az 7 dakika ve oturum başına en fazla 2 interstitial.

## Test ve build

```bash
# Debug testler
xcodebuild -project Pinly.xcodeproj -scheme Pinly \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Release compile
xcodebuild -project Pinly.xcodeproj -scheme Pinly \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

# Tek test sınıfı
xcodebuild -project Pinly.xcodeproj -scheme Pinly \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test -only-testing:PinlyTests/RouteManagerDeviationTests
```

- Bug fix için mümkünse regression test ekle.
- Auth, RevenueCat, app startup, dependency injection veya configuration değişikliğinde Debug testleri ve Release compile çalıştır.
- Testi yalnız yeşile dönsün diye zayıflatma veya silme.
- CI local-only dosyalara veya geliştirici makinesine bağımlı olmamalıdır.

## Çalışma kuralları

- Mevcut kullanıcı değişikliklerini koru; reset/history rewrite yapma.
- Remote push, deploy, production servis ayarı veya secret değişikliği açık kullanıcı onayı olmadan yapılmaz.
- Gerçek secret commit edilmez.
- Yeni feature eklemek yerine V1 release hardening kapsamını koru.
- `docs/archive/` tarihsel kayıttır; güncel ürün spec'i değildir.
- Commit mesajları `feat:`, `fix:`, `test:`, `docs:`, `chore:` veya `refactor:` önekiyle, Türkçe ve anlamlı olmalıdır.
