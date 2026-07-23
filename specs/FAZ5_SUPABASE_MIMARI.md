# FAZ 5 — Supabase Sosyal Katman Mimarisi (Fable tasarımı, 2026-07-23)

> Bu belge TASARIM katmanıdır. CRUD/ekran uygulaması Sonnet'e gider; şema/RLS/moderasyon
> değişiklikleri Fable onayı olmadan değiştirilemez.

## İlkeler
1. **Hesap sürtünmesi sıfır:** Supabase **anonymous sign-in** ile başla; kullanıcı adı sadece İLK
   yayınlama/favlama anında istenir. Sonradan Sign in with Apple'a **link** edilir (`linkIdentity`) —
   anonim geçmiş kaybolmaz. E-posta/şifre YOK.
2. **SwiftData ile gevşek bağ:** Supabase tarafında `SavedRoute` değil DTO'lar yaşar. Mevcut
   `SavedRoute.isPublic`/`supabaseId` alanları köprü — publish edilince `supabaseId` yazılır.
3. **Tüm erişim RLS üzerinden;** service key ASLA client'a girmez. Yazma yolları trigger'larla korunur.

## Şema (SQL — Supabase MCP ile uygulanacak)

```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext unique check (char_length(username) between 3 and 20
           and username ~ '^[a-z0-9_]+$'),
  display_name text check (char_length(display_name) <= 40),
  is_curator boolean not null default false,   -- "Rota Küratörü" rozeti (influencer)
  created_at timestamptz not null default now()
);

create table public_routes (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references profiles(id) on delete cascade,
  name text not null check (char_length(name) between 3 and 60),
  description text check (char_length(description) <= 280),
  city text not null,            -- normalize: küçük harf, İstanbul→"istanbul"
  country text not null,         -- ISO 3166-1 alpha-2 ("tr","fr"...)
  category text not null,        -- RouteCategory.rawValue
  places jsonb not null,         -- [SavedPlaceSnapshot] AYNI şekil (client Codable paylaşır)
  center_lat double precision not null,
  center_lon double precision not null,
  distance_km double precision,
  stop_count int not null check (stop_count between 2 and 15),
  fav_count int not null default 0,          -- trigger günceller, client YAZMAZ
  is_official boolean not null default false, -- hazır rota kataloğu (Pinly hesabı)
  status text not null default 'active'
         check (status in ('active','hidden','under_review')),
  created_at timestamptz not null default now()
);
create index on public_routes (city, status, fav_count desc);
create index on public_routes (owner, created_at desc);

create table favorites (
  user_id uuid references profiles(id) on delete cascade,
  route_id uuid references public_routes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, route_id)
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references profiles(id) on delete cascade,
  route_id uuid not null references public_routes(id) on delete cascade,
  reason text not null check (reason in ('spam','inappropriate','wrong_info','other')),
  note text check (char_length(note) <= 280),
  created_at timestamptz not null default now(),
  unique (reporter, route_id)          -- aynı rotayı iki kez raporlayamaz
);

create table blocks (
  blocker uuid references profiles(id) on delete cascade,
  blocked uuid references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create table banned_words (word citext primary key);  -- kullanıcı adı + rota adı filtresi
```

## Trigger'lar (bütünlüğün yaşadığı yer)

```sql
-- fav_count bakımı
create function bump_fav() returns trigger ... -- INSERT: +1, DELETE: -1 (security definer)

-- yayın rate limit: kişi başı günde 10 rota
create function check_publish_limit() returns trigger as $$
begin
  if (select count(*) from public_routes
      where owner = new.owner and created_at > now() - interval '1 day') >= 10 then
    raise exception 'publish_rate_limit';
  end if;
  return new;
end $$;

-- küfür filtresi: username + rota adı banned_words'e çarpıyorsa reddet
-- oto-gizleme: bir rota 3+ rapor alınca status='under_review' (feed'den düşer)
create function auto_hide_on_reports() returns trigger ...
```

## RLS Politikaları (özet — hepsi `enable row level security`)

| Tablo | select | insert | update | delete |
|---|---|---|---|---|
| profiles | herkes (authenticated) | kendi id'si | kendi satırı (username 30 günde 1 — trigger) | kendi |
| public_routes | `status='active'` OLAN herkes + kendi satırları her status'te | `owner = auth.uid()` (trigger'lar denetler) | kendi satırı (fav_count/is_official/status HARİÇ — column grant) | kendi |
| favorites | kendi satırları | kendi | — | kendi |
| reports | SADECE service role | authenticated | — | — |
| blocks | kendi satırları | kendi | — | kendi |

Engelleme etkisi client'ta uygulanır: feed sorgusu `owner not in (select blocked from blocks where blocker = auth.uid())`.
`is_official=true` satırları sadece service role yazar (katalog pipeline'ı CI'dan service key ile push eder).

## Feed sorguları (client)
- Şehir feed'i: `city = ? and status='active' order by is_official desc, fav_count desc limit 20` + keyset pagination (`created_at` imleç).
- Profil: rotaları + `count(favorites)` toplamı (view: `profile_stats`).

## Client mimarisi (SOLID)
```
RouteFeedProviding  (protokol, Pinly/Services/)
  fetchFeed(city:cursor:) / publish(SavedRoute) -> supabaseId
  favorite(routeId:) / unfavorite / myFavorites()
  report(routeId:reason:) / block(userId:)
ProfileSyncing (protokol)
  ensureUsername() / myProfile() / publicProfile(id:)
SupabaseSocialService : RouteFeedProviding & ProfileSyncing   (tek somut sınıf, supabase-swift SPM)
NoOpSocialService                                             (preview/test + "çevrimdışı" fallback)
```
- Environment key: `\.social`. ViewModel'ler protokol alır (mevcut desen).
- DTO'lar: `PublicRouteDTO: Codable` — `places` alanı MEVCUT `SavedPlaceSnapshot` ile aynı JSON şekli
  (yeni şekil türetme YOK; tek gerçek Codable).
- Anon oturum ilk `publish/favorite` çağrısında tembel açılır; başarısızsa özellik gizli kalır
  (feed salt-okunur anonim public erişim: `anon` role'e select grant).

## App Review UGC uyum listesi (ZORUNLU — 1.2 guideline)
- [ ] Rota kartında "Bildir" (4 neden) + kullanıcı "Engelle"
- [ ] EULA/Topluluk kuralları sayfası (onboarding değil, yayınlama anında tek onay)
- [ ] 24 saat içinde müdahale sözü → auto-hide trigger'ı bunu karşılar + Supabase Studio admin
- [ ] Destek e-postası ProfileTab'da mevcut (var)

## Açık kararlar (uygulama başlamadan Ferhat'a sorulacak)
1. Kullanıcı adları tamamen public mi (web'e de sızar) — varsayılan: evet, gerçek ad istenmez.
2. Rota fotoğrafları V2'de paylaşılacak mı — varsayılan: HAYIR (moderasyon yükü; foto sadece lokal
   Anı Günlüğü'nde kalır, sosyal feed metin+harita).
