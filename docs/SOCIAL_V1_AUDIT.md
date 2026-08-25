# Pinly V1 Social Hard-Off Audit

Durum: **kapalı (fail-closed)**  
Son doğrulama: 2026-08-25

## Uygulama içi erişilebilirlik

- Discover ekranındaki Topluluk Rotaları bölümü yalnızca “Çok yakında” kartıdır; feed sunmaz.
- Kayıtlı rotalardaki topluluğa yayınlama swipe aksiyonu kaldırılmıştır.
- Ortak rota oluşturma/listeleme ekranları ve `pinly://sharedroute` deep link akışı sunulmaz.
- Apple ile giriş butonu sunulmaz; V1 normal akışında Supabase hesabı oluşturulmaz.
- Sosyal ekranların kaynak kodda kalması V1.1 hazırlığıdır; bu ekranlar V1 navigasyon ağacına bağlı değildir.

## Servis katmanı kilidi

- Tek politika noktası `SocialFeaturePolicy.isEnabledInV1 == false` değeridir.
- `PinlyApp`, `SavedRoutesViewModel` ve `CommunityFeedViewModel` varsayılanları canlı Supabase servisleri yerine NoOp servislerini çözer.
- NoOp okuma çağrıları boş sonuç verir ve oturum oluşturmaz.
- NoOp mutasyonları sahte başarı üretmez; `SocialServiceError.disabled` ile fail-closed davranır.
- NoOp realtime aboneliği Supabase client veya channel oluşturmaz.
- `SupabaseSocialService` ve `SupabaseSharedRouteService` yalnızca V1.1 kaynakları olarak kalır; V1 composition root bunları enjekte etmez.

Otomatik regresyon kapsamı: `PinlyTests/SocialV1HardOffTests.swift`.

## Kod taraması

Aşağıdaki taramalar V1 hard-off değişikliğinde uygulanır:

```sh
rg -n "SupabaseSocialService.shared|SupabaseSharedRouteService.shared" Pinly --glob '*.swift'
rg -n "CommunityFeedView\(|SharedRoutesListSheet\(|CreateSharedRouteSheet\(|SharedRouteEditorView\(" Pinly --glob '*.swift'
rg -n "signInWithIdToken|signInAnonymously|\.insert\(|\.update\(|\.upsert\(" Pinly/Services --glob '*.swift'
```

İlk taramanın yalnızca canlı servislerin kendi `static shared` bildirimlerini göstermesi; ikinci taramanın ise tanımları gösterip V1 navigasyonundan bir sunum noktası göstermemesi beklenir.

## Supabase salt-okunur yayın öncesi kontrolü

Bu repo çalışmasında üretim Supabase’e bağlanılmaz ve veri değiştirilmez. Yetkili bir operatör, V1 yayını öncesi dashboard SQL Editor’da aşağıdaki **salt-okunur** sorguları çalıştırıp sonuçları release kaydına eklemelidir:

```sql
select count(*) as auth_user_count from auth.users;
select count(*) as public_route_count from public.public_routes;
select count(*) as shared_route_count from public.shared_routes;
select count(*) as favorite_count from public.favorites;
select count(*) as report_count from public.reports;
select count(*) as block_count from public.blocks;
```

Beklenti: V1 uygulama trafiği bu sayaçları artırmamalıdır. Daha önce oluşturulmuş geliştirme/test kayıtları varsa silme işlemi bu audit kapsamının dışındadır ve ayrıca onaylanmalıdır.

## V1.1 yeniden açma koşulları

Sosyal katman yalnızca şu işler tamamlandığında açılmalıdır:

1. Public payload’dan özel not, yerel kimlik ve gereksiz hassas konum alanları çıkarılmalı.
2. Uygulama içi hesap silme ve anonim hesaptan Apple hesabına güvenli geçiş tamamlanmalı.
3. UGC raporlama, engelleme ve moderasyon SLA’sı uçtan uca doğrulanmalı.
4. RLS, rate limit ve kötüye kullanım testleri staging ortamında geçmeli.
5. `SocialFeaturePolicy` için canlı servis resolver’ı ayrı bir PR ve App Review kapsamıyla değiştirilmelidir.
