# Pinly V1 Monetization Policy

Durum: kod seviyesi tamamlandı; App Store Connect, RevenueCat dashboard ve sandbox insan testi bekliyor.  
Son doğrulama: 2026-08-25

## Ürün sınırı

### Free

- Mekan kaydetme sınırsızdır.
- Rota planlama ve navigasyon çekirdek deneyimi açıktır.
- Kontrollü interstitial reklam gösterilebilir.
- GPX ve PDF dışa aktarma kilitlidir.

### Pro

- Reklam gösterilmez.
- GPX dışa aktarma açıktır.
- PDF dışa aktarma açıktır.

Pro değeri olarak mekan limiti, çevrimdışı harita, topluluk rotaları veya henüz çalışan üründe bulunmayan başka bir özellik vaat edilmez.

## Paywall ve satın alma davranışı

- Fiyatlar ve abonelik süresi RevenueCat/StoreKit `localizedPriceString` verisinden gelir; uygulamada sabit fiyat yoktur.
- Yıllık ücretsiz deneme rozeti yalnızca StoreKit’te intro offer varsa ve RevenueCat `.eligible` döndürürse gösterilir. `.unknown` durumda vaat gösterilmez.
- Otomatik yenileme, dönem, trial sonrası fiyat ve App Store’dan iptal bilgisi satın alma CTA’sıyla aynı ekrandadır.
- Satın alma ve restore sonucu yalnızca aktif `pro` entitlement doğrulandığında kilidi açar.
- Doğrulanmış `CustomerInfo`, `pinly.isPro` aynasına anında yazılır; SDK stream’i sonraki değişikliklerde aynayı düzeltir.
- GPX/PDF gate’inden açılan paywall’da satın alma başarılı olursa bekleyen export, sheet kapandıktan sonra otomatik devam eder. Kullanıcı paywall’ı satın almadan kapatırsa bekleyen export iptal edilir.
- `paywall_viewed(source)`, `purchase_started`, `trial_started`, `purchase_completed`, `restore_completed`, `export_gpx` ve `export_pdf` runtime analytics router üzerinden gerçek Firebase hedefine gider; Firebase yapılandırması olmayan clean build NoOp’a düşer.

## Reklam politikası

- Navigasyon başlatma akışında interstitial yoktur.
- Tek doğal geçiş noktası: rota tamamlandıktan sonra, completion overlay açılmadan önce.
- Link/QR paylaşımının önünde reklam yoktur; paylaşım organik büyüme döngüsüdür.
- Minimum aralık: **7 dakika**.
- Oturum başına maksimum: **2 interstitial**.
- Reklam hazır değilse kullanıcı eylemi beklemez.
- Pro kullanıcıda her çağrı reklamsız devam eder.
- UMP/ATT akışı tamamlanıp `canRequestAds` true olmadan AdMob SDK başlatılmaz ve reklam yüklenmez.
- UMP privacy-options girişi yalnız `privacyOptionsRequirementStatus == .required` olduğunda görünür.
- Profil yalnız doğum yılı tuttuğu için 13 ve 16 yaş sınır yılları daha genç kategoriye yuvarlanır; bilinen çocuk/ergen kullanıcıya ATT sorulmaz.
- Debug build Google’ın resmi test ad unit kimliğini kullanır; canlı kimlik Release’e özeldir.

Saf sıklık politikasının otomatik testleri: `PinlyTests/InterstitialFrequencyPolicyTests.swift`.

## Yayın öncesi dış sistem kontrolleri

Bu maddeler repo içinden güvenilir biçimde doğrulanamaz ve yetkili hesaplarla insan tarafından tamamlanmalıdır:

1. RevenueCat current offering’in `$rc_monthly` ve `$rc_annual` paketlerini doğru ürünlere bağladığını doğrula.
2. `pro` entitlement’ın iki üründe de aktif olduğunu doğrula.
3. App Store Connect fiyat/lokalizasyonlarını ve yearly 7 günlük intro offer’ı doğrula.
4. Sandbox’ta şu akışları gerçek cihazda çalıştır: yeni satın alma, trial uygun/uygun değil, iptal, restore, offline açılış ve grace period.
5. Free kullanıcıda uzun oturum reklam sayısını, Pro’da sıfır reklamı cihaz loglarıyla doğrula.

Yerel `Pinly.storekit` dosyasındaki fiyatlar yalnızca test storefront verisidir; production fiyatı olarak dokümana veya website’e taşınmaz.
