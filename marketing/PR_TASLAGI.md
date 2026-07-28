# PR Taslağı (Sonnet, 2026-07-29)

> **Gönderim zamanlaması notu:** Bu taslaklar App Store submit'ine yakın bir tarihte gönderilmek
> üzere hazırlandı (GROWTH_PLAN FAZ 7 / Sıralama & Takvim'de "Hafta 3-4: App Store'a SUBMIT"
> sonrası). Gönderim ANINDA köşeli parantezli alanlar ([TARİH], [LİNK] vb.) güncel duruma göre
> doldurulmalı — özellikle "beta" mı "App Store'da yayında" mı ifadesi, gönderim gününe kadarki
> gerçek duruma göre seçilmeli. Şu an (2026-07-29) uygulama TestFlight beta aşamasında; RevenueCat
> entegrasyonu ve App Store submit'i henüz tamamlanmadı — abartılı/erken "yayında" ifadesi YASAK.

---

## TR Basın Notu (Webrazzi / ShiftDelete / DonanımHaber için)

**Başlık önerisi:** Foursquare City Guide kapandı, Türkiye'nin boşluğunu yerli bir uygulama dolduruyor

**Alt başlık önerisi:** Pinly, kaydedilen mekanları yürünebilir rotalara çeviren bir gezi uygulaması
olarak [TARİH]'te TestFlight beta sürecini tamamlayıp [App Store'da yayına giriyor / genişletilmiş
beta testine açılıyor].

```
Aralık 2024'te Foursquare, en bilinen ürünü City Guide'ı kapattığını duyurdu — yıllarca milyonlarca
kullanıcının mekan kaydedip keşfettiği uygulama, Türkiye'nin küresel trafiğinin %9'unu oluşturduğu
bir pazarda birden bir boşluk bıraktı. Bu boşluğu doldurmaya çalışan yerli bir girişim: Pinly.

Pinly, kullanıcının kaydettiği mekanları statik bir listede bırakmıyor — kategoriye göre sıraya
dizip yürünebilir bir rotaya çeviriyor, adım adım (turn-by-turn) navigasyonla yürütüyor ve rota
bitince adım sayısı/mesafesiyle birlikte paylaşılabilir bir "hikaye kartı"na dönüştürüyor. Kurucu
Ferhat Akköprü, ürünün konumlandırmasını şöyle özetliyor: "Google Haritalar'da kaydedilenler listesi
kaydettiğin anda donuyor — bir daha bakmıyorsun. TikTok'ta keşfettiğin yerler de öyle, ekran
görüntüsü olarak kaybolup gidiyor. Pinly bu iki kopukluğu birleştiriyor: keşfet, kaydet, rotala,
yürü, anılaştır, paylaş."

Uygulama İstanbul, Ankara, İzmir, Antalya ve Bursa'da editör onaylı hazır yürüyüş rotalarıyla
geliyor — hiç mekan kaydetmeden de kullanılabiliyor. Turn-by-turn navigasyon, kilit ekranında
canlı takip (Live Activity), rota linkiyle arkadaşlar arası paylaşım ve 21 rozetlik bir ilerleme
sistemi öne çıkan özellikler arasında. Uygulama şu an [TestFlight beta aşamasında sınırlı davetle
test ediliyor / App Store'da ücretsiz olarak indirilebiliyor], Türkçe, İngilizce, İspanyolca,
Almanca ve Rusça dil desteğiyle geliyor.

Pinly, freemium bir modelle çalışıyor: ücretsiz sürümde 20 mekana kadar kayıt yapılabiliyor,
Pro sürüm (aylık $4.99 / yıllık $39.99) sınırsız mekan kaydı, GPX/PDF rota dışa aktarma ve
reklamsız kullanım sunuyor.

**Pinly Hakkında:** Pinly, mekan kaydetme ve yürüyüş rotası planlamayı tek uygulamada birleştiren,
Türkiye ve turist odaklı bir iOS uygulamasıdır. [TARİH]'te kuruldu, şu an [beta aşamasında /
App Store'da yayında].

**İletişim:** Ferhat Akköprü — [e-posta] — [uygulama linki]
```

**Ton notları (gönderim öncesi kontrol):**
- Kullanıcı sayısı/indirme rakamı YOK — henüz büyük bir rakam olmadığı için hiç zikredilmedi.
  Basın sorarsa "beta aşamasında, davetli kullanıcılarla test ediyoruz" cevabı yeterli.
- "%9" rakamı proje briefinde verilen sabit bir endüstri istatistiği olarak kullanıldı — gönderim
  öncesi Ferhat bu rakamın halka açık bir kaynakla (haber/analiz) desteklenebildiğini teyit etsin;
  basın bir kaynak isteyebilir.
- Fiyatlar GROWTH_PLAN'daki güncel öneriyle birebir ($4.99/$39.99) — TR bölgesel fiyat (₺129,99/
  ₺799,99 civarı) ayrıca not düşülebilir ama basın metninde ana fiyat USD ile bırakıldı (uluslararası
  yayın ihtimaline karşı).

---

## Product Hunt Launch Taslağı (EN)

**Tagline (53/60):** `Turn saved places into walkable days, not screenshots`

**Description (kısa, ürün odaklı):**
```
Pinly turns the places you save into walkable routes — pick a category, set your stop order,
follow turn-by-turn navigation, and end the day with a shareable story card. Comes with curated
starter routes in Istanbul, Ankara, Izmir, Antalya, and Bursa so you can try it with zero setup.
Free up to 20 saved places; Pro unlocks unlimited places, GPX/PDF export, and an ad-free experience.
```

**Maker'ın ilk yorumu (samimi, hikaye anlatan ton):**
```
Hey Product Hunt 👋

I'm Ferhat, solo indie dev behind Pinly. This started from a personal annoyance: my phone had
dozens of screenshots of "places to visit" that I never actually visited, because a screenshot
isn't a plan. Around the same time, Foursquare shut down City Guide — an app a lot of us used for
exactly this — and Turkey (where I'm based) was a meaningful chunk of its traffic. That gap felt
worth trying to fill.

So Pinly does one specific thing: it turns saved places into an actual walkable route — you pick
categories, order your stops, and it gives you turn-by-turn walking directions with live tracking
on your lock screen. When you finish, it makes you a shareable "story card" with your stats, so the
day becomes something you can actually look back on (or send to a friend, who can import your exact
route with one tap).

It's still early — [TestFlight beta / just launched], five stops-worth of starter routes so far in
Istanbul, Ankara, Izmir, Antalya, and Bursa, more coming. I'd love feedback on the core loop
(save → route → walk → remember) before I lean harder into any one direction. Happy to answer
anything about the build (SwiftUI/SwiftData/MapKit) or the "why" behind it.

Thanks for checking it out 🙏
```

**Gönderim öncesi kontrol listesi:**
- [ ] Köşeli parantezli alanları (`[TARİH]`, `[TestFlight beta / just launched]`, `[e-posta]`,
      `[uygulama linki]`) gönderim gününe göre doldur
- [ ] "%9" istatistiği için tek cümlelik kaynak notu hazır bulundur (basın sorarsa)
- [ ] PH gönderiminden önce ekran görüntüleri (`marketing/ASO_METIN_SETI.md` not 2'deki 6 kare
      sırası) + varsa kısa demo GIF hazır olsun — PH listing'i görselsiz zayıf performans gösterir
