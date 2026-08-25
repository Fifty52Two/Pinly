# Pinly V1 App Store Metadata — TR / EN

Production fiyatı bu dosyada yazılmaz. App Store satın alma ekranı fiyat ve trial gerçeğinin tek kaynağıdır. Domain ve App Store ID gelmeden URL alanları placeholder olarak kalır.

## Türkçe

- Ad: `Pinly: Rota & Mekan Keşfi` (25/30)
- Alt başlık: `Kaydet, rotala, yürü, yaşa` (26/30)
- Keywords: `gezilecek,yerler,gezi,planlayıcı,yürüyüş,harita,kafe,müze,istanbul,seyahat,günlük,tur`
- Promotional text: `Kaydettiğin mekanları yürünebilir günlere çevir. Rotanı kur, adım adım yürü, fotoğraflarla anılaştır.`
- Support URL: `https://<PRODUCTION_HOST>/support/`
- Marketing URL: `https://<PRODUCTION_HOST>/`
- Privacy Policy URL: `https://<PRODUCTION_HOST>/privacy/`
- Privacy Choices URL: `https://<PRODUCTION_HOST>/privacy-choices/`

### Açıklama

Telefonunda biriken “gidilecek yerler” ekran görüntülerini gerçek bir yürüyüş planına çevir.

Pinly ile mekan kaydet, duraklarını sırala, yürüyüş rotanı oluştur ve adım adım navigasyonla ilerle. İstanbul, Ankara, İzmir, Antalya ve Bursa'daki hazır rotalarla hiç kurulum yapmadan başlayabilirsin.

ÖNE ÇIKANLAR

- Adresle, konumla veya haritada pin bırakarak mekan kaydet
- Kategorilere göre rota oluştur ve durakları sürükleyerek sırala
- Yürüyüş navigasyonu ve kilit ekranında Live Activity
- Rotadan sapınca otomatik yeniden hesaplama
- QR kod veya link ile rota paylaşma ve içe aktarma
- Tamamlanan rotaları fotoğraflı anı kartına dönüştürme
- 21 rozet, streak, haftalık rapor ve kişisel istatistikler
- Türkçe, İngilizce, İspanyolca, Almanca ve Rusça

FREE VE PRO

Free sürümde sınırsız mekan kaydı, rota planlama ve navigasyon vardır; kontrollü reklam gösterilebilir. Pinly Pro GPX/PDF dışa aktarma ve reklamsız kullanım ekler.

Güncel fiyat, abonelik dönemi ve varsa deneme uygunluğu satın alma öncesi App Store ekranında gösterilir. Abonelik otomatik yenilenir; Apple ID ayarlarından yönetilebilir veya iptal edilebilir. Satın alımları uygulama içinden geri yükleyebilirsin.

Koşullar: `https://<PRODUCTION_HOST>/terms/`  
Gizlilik: `https://<PRODUCTION_HOST>/privacy/`

## English

- Name: `Pinly: City Walks & Places` (26/30)
- Subtitle: `Save, route, walk, remember` (27/30)
- Keywords: `travel,planner,istanbul,guide,map,itinerary,walking,tour,diary,cafe,museum,routes`
- Promotional text: `Turn saved places into walkable days. Build a route, follow it step by step, and keep the memories.`
- Support URL: `https://<PRODUCTION_HOST>/en/support/`
- Marketing URL: `https://<PRODUCTION_HOST>/en/`
- Privacy Policy URL: `https://<PRODUCTION_HOST>/en/privacy/`
- Privacy Choices URL: `https://<PRODUCTION_HOST>/en/privacy-choices/`

### Description

Turn the “places to visit” screenshots on your phone into a real walking plan.

Save places in Pinly, order your stops, build a walking route, and navigate step by step. Start immediately with curated routes in Istanbul, Ankara, Izmir, Antalya, and Bursa.

HIGHLIGHTS

- Save a place by address, current location, or a pin on the map
- Build routes by category and drag stops into your preferred order
- Walking navigation with Live Activity on the Lock Screen
- Automatic recalculation when you leave the route
- Share and import routes with a QR code or link
- Turn completed routes and photos into memory cards
- 21 badges, streaks, weekly reports, and personal stats
- Available in English, Turkish, Spanish, German, and Russian

FREE AND PRO

Free includes unlimited saved places, route planning, and navigation, with controlled ads. Pinly Pro adds GPX/PDF export and removes ads.

The current price, subscription period, and any trial eligibility are shown by the App Store before purchase. Subscriptions renew automatically and can be managed or canceled in Apple ID settings. Purchases can be restored in the app.

Terms: `https://<PRODUCTION_HOST>/en/terms/`  
Privacy: `https://<PRODUCTION_HOST>/en/privacy/`

## Screenshot set — 6 frames

1. Home/places: TR `Kaydettiğin yerler, tek haritada` · EN `Every saved place, one map`
2. Route builder: TR `Gününü yürünebilir bir rotaya çevir` · EN `Turn your day into a walkable route`
3. Navigation: TR `Adım adım yürü` · EN `Walk it, step by step`
4. Memory card: TR `Rotanı anıya dönüştür` · EN `Turn the route into a memory`
5. Starter routes: TR `Şehrini hemen keşfet` · EN `Explore your city right away`
6. Progress: TR `Her yürüyüş ilerleme` · EN `Every walk counts`

Screenshot'lar gerçek simulator/device UI'dan alınmalı; sahte özellik, cihaz çerçevesi içinde okunamaz küçük metin veya App Store'dan farklı fiyat kullanılmamalı.

## Review notes — English

Pinly V1 does not require an account. Social/community and shared collaborative route features are disabled in this release and do not create a Supabase session.

Free users can save unlimited places and use the core route-planning and navigation experience. Pro only unlocks GPX/PDF export and removes ads. To review subscriptions, use the sandbox account attached in App Store Connect and test both purchase and Restore Purchases from Profile → Pinly Pro.

Location is used to plan and navigate walking routes. Background location is enabled only during active navigation, displays the iOS background indicator, and stops when navigation ends or after a two-hour safety timeout. HealthKit read access is optional and only adds step count/walking distance to a completed-route summary; the app does not write Health data or upload it to our services.

AdMob starts only after the UMP consent flow permits ad requests. ATT is requested only when applicable. Users can reopen ad privacy choices from Profile → Privacy Choices. Interstitials never appear when navigation starts; they are capped to a minimum seven-minute interval and two per session. Pro users receive no ads.

Privacy Policy: `https://<PRODUCTION_HOST>/en/privacy/`  
Terms: `https://<PRODUCTION_HOST>/en/terms/`  
Support: `https://<PRODUCTION_HOST>/en/support/`
