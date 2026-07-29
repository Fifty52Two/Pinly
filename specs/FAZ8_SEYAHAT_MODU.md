# FAZ 8 — Seyahat Modu: Kemik Kitle & Uluslararası Büyüme (2026-07-29)

> Bu belge TASARIM katmanıdır — uygulamaya başlamadan önce Ferhat'ın onayı gerekir.
> Yön kararı AskUserQuestion ile alındı: sosyal katmanı büyütme + retention + uluslararası
> genişleme öncelikli; AI rota asistanı ("az maliyetli tam olmaz") ve iCloud Sync/Apple Watch
> gibi mimari yükü büyük özellikler bilinçli olarak ERTELENDİ. Ferhat'ın somut isteği: "yurt
> dışı gezisi yapacak kişiler önceden rota belirleyebilsin" + "sevgililer/arkadaşlar birlikte
> rota yapabilsin" — appi karmaşıklaştırmadan, hem profesyonel hem sıcak, kemik kitle kuracak.

## İlke

Üç özellik de MEVCUT altyapı üzerine ince katman — yeni bir mimari paradigma yok:
- Seyahat Planlama: SwiftData'da yeni tek model (`Trip`), var olan `SavedRoute` +
  `StarterRouteService` + FAZ5 feed'i üstüne kurulur.
- Birlikte Rota: Supabase'de 2 küçük tablo eklenir, gerçek zamanlı (WebSocket/Realtime) YOK —
  polling/pull-to-refresh yeterli ("basit tut" ilkesi).
- Kemik kitle mekanikleri: var olan `fav_count`/`is_curator` alanlarının AÇILMASI, yeni backend
  değil.

---

## 8.1 Seyahat Planlama (Yaklaşan Gezi)

**Neden:** Bugün eklenen 30 şehirlik rota kataloğu (9 TR + 20 Avrupa) + FAZ5 topluluk feed'i şu an
sadece "buradayken keşfet" (Yakınımda/Keşfet) akışında kullanılıyor. Turist kullanıcının asıl
ihtiyacı GİTMEDEN ÖNCE planlamak — bu, uluslararası büyümenin gerçek kaldıracı.

### Model (SwiftData, yerel — Supabase gerekmez)

```swift
@Model
class Trip {
    @Attribute(.unique) var id: UUID
    var city: String              // StarterRouteService/feed şehir anahtarıyla aynı normalize
    var country: String?
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    /// Gün bazlı sıralı rota referansları — SavedRoute silinirse gün boş kalır (crash yok),
    /// FAZ5.2'deki placeId deseninin aynısı (dayanıklılık > sıkı referans).
    var dayRouteIDsData: Data     // [UUID?] JSON — index = gün no (0 = 1. gün)
}
```

### Akış
1. Rotalar sekmesine "Yaklaşan Seyahatler" yatay kart şeridi (SavedRoutesView'in üstüne, mevcut
   "hazır rota" kartlarıyla aynı görsel dil).
2. "+ Yeni Seyahat" → şehir seç (30 şehirlik katalog + serbest metin) + tarih aralığı (DatePicker
   range) → `Trip` oluşur.
3. Trip detayında gün gün ("1. Gün", "2. Gün"...) rota atama: her gün için üç kaynaktan seçim —
   (a) `StarterRouteService.loadCityCatalog(city:)` (offline, hazır rota), (b)
   `SocialServicing.fetchFeed(city:)` (topluluk rotaları, `is_official` dahil), (c) kullanıcının
   kendi `SavedRoute`'ları. Seçilen rota o günün slotuna yazılır (referans, kopyalama değil).
4. **Hatırlatma bildirimi:** `NotificationScheduling` protokolüne `scheduleTripReminder(trip:)`
   eklenir (mevcut haftalık rapor/seri bildirimi deseniyle aynı) — `startDate - 3 gün`'de yerel
   bildirim: "{şehir} seyahatin yaklaşıyor — {N} rotan hazır, göz at."
5. Seyahat bitince (tüm günler `RouteHistory`'ye düşünce) opsiyonel "Seyahat Özeti" — V2, MVP'de
   şart değil.

### Yeni dosyalar (öngörülen)
`Pinly/Models/Trip.swift`, `Pinly/Views/trip/TripListView.swift` +
`TripDetailView.swift`/`TripViewModel.swift`, `NotificationScheduling`'e 1 metot eklentisi.

---

## 8.2 Birlikte Rota Planlama (Together)

**Neden:** "Sevgililer/arkadaşlar birlikte rota yapabilsin" — sosyal katmanın SICAK tarafı,
FAZ5'in public feed'inden farklı: burada rota PUBLIC değil, sadece davet edilenlere özel.

### Şema eki (Supabase — mevcut `public_routes`tan AYRI, farklı görünürlük kuralı)

```sql
create table draft_routes (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  city text,
  places jsonb not null default '[]',   -- [SavedPlaceSnapshot + addedBy: uuid] dizisi
  invite_code text unique not null,     -- kısa rastgele kod, deep link'te kullanılır
  status text not null default 'open' check (status in ('open','finalized')),
  created_at timestamptz not null default now()
);

create table draft_participants (
  draft_id uuid references draft_routes(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (draft_id, user_id)
);
```

RLS: `draft_routes`/`draft_participants` SADECE `draft_participants`'ta kayıtlı kullanıcıya açık
(owner dahil, owner insert anında kendini participant ekler). `invite_code` ile katılım bir
Postgres fonksiyonu (`join_draft(code text)`, security definer) üzerinden yapılır — kod bilmek tek
yetki kanıtı, ekstra onay akışı yok (sürtünme sıfır ilkesiyle tutarlı).

### Client akışı
1. `SavedRoutesView`'de var olan rotaya (veya yeni boş taslağa) "Birlikte Planla" aksiyonu →
   `draft_routes` insert edilir, `invite_code` üretilir.
2. Mevcut `RouteSharePickerView`/`ShareLink` deseniyle aynı şekilde deep link paylaşılır:
   `pinly://joindraft?code=XXXX`.
3. Davetliyi açan kişi: anonim oturum zaten `ensureSession()` ile sessizce kurulur → `join_draft`
   RPC'si çağrılır → taslağı görür, mekan ekleyebilir (kendi eklediği `addedBy` alanıyla
   işaretlenir, UI'da "Ayşe ekledi" rozeti).
4. **Gerçek zamanlı senkron YOK** — pull-to-refresh (mevcut `.refreshable` deseni). Basit tut
   ilkesi: WebSocket/Realtime karmaşıklığı bu faz için gereksiz.
5. Owner "Rotayı Onayla" deyince taslak normal `SavedRoute`'a dönüşür (`status='finalized'`).
6. Rota tamamlanınca: mevcut Anı Günlüğü altyapısı üstüne "Birlikte tamamlandı 💛" rozeti/metni —
   çoklu-kullanıcı foto senkronu (ikisinin çektiği fotoların birleşmesi) V2'ye bırakılır, MVP'de
   sadece ortak tamamlama anısı yeterli.

### Yeni dosyalar (öngörülen)
`Pinly/Services/DraftRouteService.swift` (yeni protokol, `SocialService.swift`'e karışmaz — ayrı
görünürlük kuralı ayrı protokol hak eder), `Pinly/Views/social/JoinDraftView.swift`,
`ContentView.swift`'e `joindraft` deep link handler'ı (mevcut `addplace`/`route` desenine ek).

---

## 8.3 Kemik Kitle Mekanikleri (hafif, yeni backend YOK)

- **Rota Küratörü aktivasyonu:** `profiles.is_curator` zaten şemada var, hiç kullanılmıyor.
  Basit eşik: N rota yayınlamış + M toplam fav almış kullanıcı küratör sayılır (client-side
  hesap, `myPublishedRoutes()` zaten bunu döndürüyor — ekstra sorgu gerekmez). Profilde +
  feed kartlarında küçük rozet ikonu.
- **"Bu ay öne çıkanlar":** feed sorgusuna `created_at > ay_başı` filtresi eklenmiş bir varyant —
  yeni tablo/trigger gerekmez, var olan `fav_count` sıralamasının bir view'ı.
- **Seyahat hatırlatma bildirimi** (8.1) zaten bir geri-çağırma/retention mekanizması —
  ayrı bir "retention altyapısı" fazı açmaya gerek yok, iki özelliğin doğal sonucu.

---

## Kapsam DIŞI (bilinçli — "appi karmaşıklaştırma" talimatına uyularak)

- iCloud Sync / CloudKit çoklu cihaz senkronu
- Apple Watch companion
- AI rota asistanı (Claude API) — kullanıcı kararı: maliyet/fayda oranı şu an düşük
- Draft route'larda gerçek zamanlı (WebSocket) senkron
- Çoklu-kullanıcı foto birleştirme (Birlikte anı kartı V2'ye bırakıldı)

## Açık kararlar (uygulama başlamadan Ferhat'a sorulacak)
1. Trip'in "gün" sınırı var mı (ör. max 14 gün) — UI karmaşıklığını sınırlamak için öneri: evet, 14.
2. Birlikte taslakta katılımcı sayısı sınırı — öneri: 2-4 kişi (çift/arkadaş grubu senaryosu,
   büyük grup organizasyonu kapsam dışı).
3. Küratör rozeti otomatik mi açılsın yoksa manuel onay (Supabase dashboard'dan) mı — spam/kalite
   riskine göre öneri: otomatik ama `banned_words`/rapor sayısı yüksek kullanıcılar hariç.
