# FAZ 3 — Anı Günlüğü: Migration Tasarımı + Mimari (Fable) / Uygulama Spec'i (Sonnet)

## Veri tasarımı (Fable kararları — değiştirme)

**1. `RouteHistory`'ye tek yeni alan:**
```swift
/// Durak bazlı anı fotoğrafları: JSON [RouteMemoryPhoto]. nil = eski kayıt/fotosuz.
var memoryPhotosData: Data? = nil
```
- Optional + default nil ⇒ SwiftData **hafif migration**, custom plan GEREKMEZ. (Yeni zorunlu alan
  ekleme YASAK — eski kayıtlar kırılır.)
- Şekil: `struct RouteMemoryPhoto: Codable { let stopIndex: Int; let stopName: String; let fileName: String }`
  — `stopName` kopya olarak tutulur (Place silinse de günlük kartı isim gösterebilir; SavedRoute
  snapshot deseninin aynısı).

**2. Depolama — `RouteMemoryStoring` (YENİ protokol, Pinly/Services/):**
```swift
protocol RouteMemoryStoring: AnyObject {
    func save(_ image: UIImage, historyID: UUID, stopIndex: Int) throws -> String  // fileName döner
    func load(fileName: String) -> UIImage?
    func deleteAll(historyID: UUID)
}
```
- Somut: `DefaultRouteMemoryStore` → `Documents/RouteMemories/<historyID>/<stopIndex>_<uuid>.jpg`,
  1200 px uzun kenar, 0.8 JPEG (PlacePhotoStore ile aynı sıkıştırma sabitleri — sabitleri paylaşan
  küçük `ImageDownscaler` yardımcısına çıkar, kopyalama).
- **Mekan fotoğrafından AYRI depo** (bilinçli): geçmiş kaydı, mekan silinse de bozulmamalı. Kullanıcı
  durakta foto çekince varsayılan SADECE anı deposuna yazılır; "mekan fotoğrafı olarak da kaydet"
  toggle'ı (varsayılan açık) aynı UIImage'ı mevcut `PlacePhotoStoring`'e DE yazar. İki sistem
  birbirinin dosyasına referans VERMEZ.
- Environment key: `\.routeMemories`. RouteHistory silinirken `deleteAll(historyID:)` çağrılır
  (RouteHistoryView delete + veri silme akışı).

**3. Kart üretimi — `MemoryCardComposing` (YENİ protokol):**
```swift
protocol MemoryCardComposing {
    func composeStory(history: RouteHistory, photos: [UIImage], mapSnapshot: UIImage?) -> UIImage  // 1080×1920
    func composePost(history: RouteHistory, photos: [UIImage], mapSnapshot: UIImage?) -> UIImage   // 1080×1350
}
```
- Somut sınıf ImageRenderer ile SwiftUI view'ı render eder (RouteShareCard deseni). Harita:
  `MKMapSnapshotter` + polyline overlay çizimi (snapshot options: rota bounding box + %20 pad,
  `pointForCoordinate` ile polyline'ı context'e elle çiz — snapshotter overlay çizmez, bilinen tuzak).
- Yerleşim: üst 1/3 harita izi (seigaiha krem zemin, sage polyline, lacivert duraklar) → orta foto
  kolajı (1 foto: tam genişlik; 2-3: mozaik; 4+: 2×2 + "+n") → alt bant: rota adı, tarih,
  km / dk / adım `StatChip` dili, sağ altta küçük Pinly wordmark. Renkler SADECE PinlyTheme'den.

## Akış değişiklikleri
1. **Durakta foto:** `RatingSheetView`'e not alanının üstüne "Fotoğraf ekle" satırı — mevcut
   `CameraPicker` + PhotosPicker ikilisi (PlaceFormComponents'teki bileşen yeniden kullanılır).
   Durak başına en fazla 3 foto. Çekilen foto ANINDA `RouteMemoryStoring`'e yazılır (rota
   tamamlanmadan app ölürse foto kaybolmasın); `RouteManager`'a foto state'i GİRMEZ —
   `RouteSummaryViewModel` `[Int: [String]]` (stopIndex→fileNames) taşır, `completeRoute` yazımında
   `memoryPhotosData`'ya serialize eder.
2. **Tamamlama sekansı:** mevcut sıra korunur (badge/history/HealthKit → interstitial →
   RouteCompletionOverlay). Overlay'e "Hikayeni Paylaş" birincil butonu eklenir → story/post format
   seçimi → `ShareLink`. Interstitial paylaşım niyetinden ÖNCE kalır (mevcut yerinde), paylaşımın
   ortasına reklam GİRMEZ.
   **DİKKAT — FAZ 1'de bu kapanış akışına soft paywall eklendi (2026-07-23):** overlay kapanış
   closure'ı artık üç dallı — review prompt / `viewModel.consumeSoftPaywallOffer()` → soft paywall
   sheet (rota akışı AÇIK kalır, reset+dismiss sheet'in onDismiss'inde) / doğrudan reset+dismiss.
   "Hikayeni Paylaş" bu yapıyı BOZMADAN eklenecek: paylaşım overlay İÇİNDEN yapılır (overlay
   kapanmadan), kapanış closure'ının dallanmasına dokunulmaz. Soft paywall'ın sökülen view'dan
   sheet sunamama tuzağına dikkat (bug geçmişi: RouteSummaryView kapanış sırası).
3. **Günlük ekranı:** `RouteHistoryView` yeniden düzenlenir — foto'lu kayıtlar büyük kart (ilk foto
   başlık görseli + istatistik şeridi), fotosuz eskiler mevcut satır görünümünde. Karta dokun →
   `MemoryDetailView`: tüm fotolar + harita + "Yeniden Paylaş".
4. **Analytics:** `memory_photo_added`, `memory_card_shared(format)` → `AnalyticsEvent` enum'una ekle.

## Sonnet görev listesi (bu sırayla)
- [ ] `RouteMemoryPhoto` + `RouteHistory.memoryPhotosData` + decode/encode yardımcıları (test: eski
      kayıt nil okunur, yeni kayıt round-trip)
- [ ] `RouteMemoryStoring` + `DefaultRouteMemoryStore` + `\.routeMemories` + Mock (test: save/load/deleteAll)
- [ ] `ImageDownscaler` çıkarımı (PlacePhotoStore refactor — davranış değişmez, mevcut testler yeşil kalmalı)
- [ ] RatingSheetView foto satırı + RouteSummaryViewModel foto state (test: stopIndex eşleme)
- [ ] `MemoryCardComposing` + somut sınıf + snapshot testi (harita nil'ken de kart üretmeli)
- [ ] RouteCompletionOverlay "Hikayeni Paylaş" + RouteHistoryView/MemoryDetailView UI
- [ ] Analytics event'leri + 5 dil lokalizasyon anahtarları (TR anahtar metinleri Fable'dan hazır:
      "Fotoğraf ekle", "Hikayeni Paylaş", "Günlük", "Yeniden Paylaş", "Mekan fotoğrafı olarak da kaydet")
- [ ] Veri silme akışına RouteMemories klasörü dahil et

**Kabul ölçütü:** 3 duraklı rotada 2 durakta foto çek → tamamla → story kartında 2 foto + harita izi;
uygulamayı öldürüp aç → Günlük'te kart duruyor; RouteHistory kaydını sil → RouteMemories klasörü boş.
