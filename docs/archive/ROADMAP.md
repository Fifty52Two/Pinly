# Pinly — Durum Değerlendirmesi & Yol Haritası (2026-07-06)

> Bu belge mevcut durumun dürüst bir fotoğrafı + kısa/orta/uzun vadeli plan + test stratejisidir.
> `IMPROVEMENT_PLAN.md` teknik iş listesini tutar; bu dosya ürün/büyüme perspektifidir.

---

## 1. Mevcut Durum Değerlendirmesi (dürüst karne)

| Alan | Not | Açıklama |
|---|---|---|
| Mimari | **A-** | MVVM + protokol servis katmanı, DI, SRP dosya yapısı. Eksik: test yazılmamış olması mimarinin test edilebilirliğini henüz kanıtlamıyor. |
| UI/UX | **B+** | Doğal palet, onboarding, tutarlı tasarım sistemi. Eksik: boş durumlar bazı ekranlarda zayıf, Dynamic Type/VoiceOver denetimi yapılmadı, iPad düzeni yok. |
| Özellik seti | **B+** | Mekan + rota + navigasyon + rozet + rapor + import/export + pinleme. Çekirdek döngü tam. Eksik: sosyal katman (feed/takip) yok — viral büyüme tavanını sınırlıyor. |
| Gelir altyapısı | **C** | Paywall UI hazır ama ödeme placeholder (herkes Pro olabiliyor). AdMob test ID'de. **Yayın engeli #1.** |
| Test | **D** | Sıfır otomatik test. Manuel test de sistematik değil. |
| Dağıtım | **F** | App Store'da değil (Apple Developer hesabı yok). Landing page hazır ama domain yok. |
| Analitik/Gözlemlenebilirlik | **F** | Crash reporting yok, analytics yok, A/B altyapısı yok. Yayında kör uçarsın. |

**Özet:** Kod tarafı yayın kalitesine yaklaştı; ürünün önündeki gerçek engeller kod dışı: hesap, ödeme, test disiplini, analitik ve dağıtım.

---

## 2. Fonksiyonlar Çalışıyor mu? — Test Stratejisi

### 2.1 Şu anki gerçek
Otomatik test **yok**. Simülatörde smoke test yapıldı (açılış, onboarding, ana ekran, deep link, lokalizasyon) ama navigasyon/GPS akışları simülatörde tam test **edilemez**.

### 2.2 Manuel test checklist'i (cihazda, yayın öncesi zorunlu)
- [ ] **Onboarding:** ilk açılış 3 sayfa → izinler doğru sırada (önce konum, sonra bildirim)
- [ ] **Mekan CRUD:** ekle (adresle + haritada pinle + hızlı ekle) / düzenle / sil / ara / filtrele / sırala
- [ ] **Haritada Pinle:** pin sürükleme hissi, adres çözümleme, koordinatın kaydedildiği (mekan haritada doğru yerde mi?)
- [ ] **Rota akışı:** kategori seç → mekan seç → rota hesaplanıyor → haritada çiz
- [ ] **Navigasyon (SOKAKTA YÜRÜYEREK):** talimat ilerleme, 30m varış algısı, duraklama/devam, rotadan sapınca yeniden hesaplama, Live Activity kilit ekranı, tamamlama overlay + paylaşım kartı
- [ ] **Kayıtlı rotalar:** planla → kaydet → listeden başlat → düzenle → sil; uzaklık uyarısı
- [ ] **Paylaşım:** QR üret/tara, rota linki (WhatsApp'tan gönder→aç), Swarm JSON import, GPX/PDF export (Pro gate)
- [ ] **Rozetler:** mekan/ziyaret/rota eşiklerinde banner çıkıyor mu; sabahçı kuş (07-09 arası rota başlat)
- [ ] **Freemium:** 20. mekandan sonra 4 gate noktasının hepsi paywall açıyor mu (liste +, harita +, QR, deep link)
- [ ] **5 dil:** her dilde ana akış (özellikle RU/DE metin taşmaları)
- [ ] **Dark mode:** tüm ekranlar
- [ ] **Kesinti senaryoları:** navigasyonda arama gelirse, uygulama arka plana atılırsa, konum kapatılırsa

### 2.3 Otomatik test planı (mimari artık hazır)
1. **Unit (ilk hafta, ~1 gün iş):** `PlaceImporter` (URL build/parse round-trip, Swarm parse, GPX çıktısı), `LocalEntitlementService` (limit + legacy migration — mock UserDefaults ile), `DefaultBadgeService.check` eşikleri, `PlacesListViewModel` filtre/sıralama, `RouteManager` segment hizalama (başarısız segment placeholder'ı)
2. **Snapshot test (opsiyonel):** paylaşım kartı + onboarding sayfaları
3. **UI test (yayın sonrası):** onboarding → mekan ekle → rota kur happy path
4. **TestFlight beta (hesap alınınca):** 10-20 gerçek kullanıcı, İstanbul'da fiilen yürüyecek 3-5 kişi şart

---

## 3. KISA VADE (0–1 ay) — "Yayınlanabilir yap"

Öncelik sırasıyla; 1-4 bloklayıcı, gerisi paralel:

1. **Apple Developer hesabı** ($99) — her şeyin ön koşulu
2. **RevenueCat entegrasyonu** — SPM paketi zaten ekli; `LocalEntitlementService` → `RevenueCatEntitlementService` (protokol sayesinde tek dosya değişir). Ürünler: `pinly_pro_monthly` $4.99, `pinly_pro_yearly` $39.99. Paywall'daki sahte "Pro'ya Geç" kaldırılmadan YAYINLANAMAZ.
3. **AdMob gerçek ID'ler + ATT** — `NSUserTrackingUsageDescription` + `ATTrackingManager` izni; reklamsız başlayıp v1.1'de açmak da meşru (ilk izlenim temiz olur — öneririm)
4. **Crash + analytics:** Firebase Crashlytics ya da Sentry + basit event'ler (onboarding tamamlama, mekan ekleme, rota başlatma/tamamlama, paywall görüntüleme/dönüşüm). Bunlar olmadan D1/D30 retention'ı ölçemezsin.
5. **Unit test paketi** (§2.3-1) — CI olarak GitHub Actions'ta `xcodebuild test`
6. **App Store varlıkları:** 6.5"+5.5" ekran görüntüleri (doğal paletle, TR+EN), önizleme videosu (rota akışı 15sn), başlık/altbaşlık keyword araştırması ("gezi rotası", "yürüyüş rotası", "mekan kaydetme", "seyahat planlayıcı")
7. **Gizlilik:** App Privacy formu (konum, sağlık, reklam takibi), privacy policy sayfası (landing'e eklenir), `pinly.app` domain'i alınıp landing yayınlanır
8. **Cihazda saha testi** (§2.2 checklist) — özellikle navigasyonu sokakta yürüyerek

## 4. ORTA VADE (1–4 ay) — "Tutundur ve büyüt"

Sektör gerçeği: seyahat uygulamalarında D1 retention ~%18, D30 ~%2.8; D30 %5+ iyi sayılıyor. Post-install davranış (7+ gün) mağaza sıralamasını doğrudan etkiliyor. Hedef: **D30 ≥ %5.**

1. **Retention mekanikleri:**
   - Akıllı yerel bildirimler: "Kadıköy'desin — 3 kayıtlı mekanın 500m içinde" (geofence), pazar haftalık rapor bildirimi zaten var
   - Rozet serisi bildirimi ("2 gündür seri — bugün de aç")
   - Widget'ı zenginleştir: "en yakın kaydedilmiş mekan" widget'ı
2. **Sosyal-hafif özellikler (backend'siz):**
   - Hazır rota paketleri: 5-10 küratörlü İstanbul rotası uygulama içinde (JSON bundle) — boş uygulama problemi çözülür, ilk gün değeri artar
   - Rota linklerini web'de önizleme: `pinly.app/r/...` → landing'de rota kartı gösterip App Store'a yönlendir (paylaşılan linkler şu an uygulaması olmayanlar için ölü)
3. **Keşfet'e harita modu + "gitmediklerim" filtresi** (backlog'da)
4. **Toplu mekan silme + iCloud Sync** (SwiftData+CloudKit — kullanıcı cihaz değiştirince veri kaybı şu an %100)
5. **ASO iterasyonu:** haftalık keyword takibi, ekran görüntüsü A/B (mağaza sayfası dönüşümünde %2-3 artış = yüzlerce organik indirme)
6. **İçerik pazarlaması:** Foursquare/Swarm kapanışı nostaljisi üzerinden "check-in geçmişini kurtar" anlatısı — Reddit r/foursquare, ekşi sözlük, X; Swarm import Pinly'nin en keskin edinim kancası
7. **TestFlight → kademeli yayın:** önce TR, geri bildirimle EN pazarları

## 5. UZUN VADE (4–12 ay) — "Platformlaş"

1. **Supabase backend + hesap sistemi:** rota feed'i, takip, beğeni — viral döngünün gerçek hali. Influencer'ların rota paylaşabildiği "rota = içerik" modeli (CLAUDE.md'deki plan geçerli)
2. **AI rota asistanı:** "Kadıköy'de 3 saatim var, kahve + sahaf turu öner" → Claude API, Supabase Edge Function proxy'siyle (client'ta key yok). Bu, 2026'da mağaza aramasının AI-öneri katmanında öne çıkmak için de değerli
3. **Offline harita (Pro):** Mapbox — Pro'nun en satan vaadi turistler için
4. **B2B/turizm iş birlikleri:** belediye/turizm ofisi küratörlü rotalar, otel QR paketleri
5. **Apple Watch companion:** navigasyon talimatları bilekte — yürüyüş uygulaması için doğal genişleme
6. **MENA/Balkan lokalizasyonu** pazara göre (AR kararı daha önce "hayır"dı; veri gelince yeniden değerlendir)

## 6. Profesyonellik Checklist (sürekli)

- [ ] Dynamic Type + VoiceOver denetimi (accessibility yayın kalitesinin parçası)
- [ ] `prefers-reduced-motion`a saygı (animasyonlar)
- [ ] iPad düzeni ya da açıkça iPhone-only kalma kararı
- [ ] Hata durumları: ağ yokken rota hesaplama, geocode başarısızlığı — kullanıcıya açık mesaj
- [ ] Sürüm/changelog disiplini, semantic versioning
- [ ] `SavedPlaceSnapshot`'a placeId (isimle eşleşme kırılganlığı — IMPROVEMENT_PLAN'da kayıtlı)
- [ ] Onboarding'e "Swarm'dan içeri aktar" kısayolu (en güçlü kanca ilk 30 saniyede görünmeli)

## 7. Kuzey Yıldızı Metrikleri

| Metrik | Hedef (ilk 6 ay) |
|---|---|
| D1 retention | ≥ %25 (sektör ~%18) |
| D30 retention | ≥ %5 |
| Onboarding tamamlama | ≥ %80 |
| Mekan ekleyen kullanıcı (ilk oturum) | ≥ %60 |
| Rota tamamlayan/hafta | takip et, baz çıkar |
| Paywall dönüşümü | %2-4 (utility freemium normali) |
| Paylaşım kartı/link paylaşan | ≥ %10 (viral katsayı tohumu) |
