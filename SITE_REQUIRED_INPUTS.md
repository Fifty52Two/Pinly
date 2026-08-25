# Pinly Website — Yayın İçin Zorunlu Girdiler

Website ve uygulama içi hukuk bağlantıları production'a alınmadan önce aşağıdaki bilgiler kullanıcı tarafından doğrulanmalıdır. Bu alanlar bilinçli olarak uydurulmadı.

## Kimlik ve iletişim

- [ ] Yayıncının tam yasal adı / şirket unvanı
- [ ] Veri sorumlusunun aynı kişi/kurum olup olmadığı
- [ ] Geçerli destek e-posta adresi
- [ ] Gizlilik talepleri için e-posta adresi (destekle aynı olabilir)
- [ ] Tebligat/posta adresi ve ülke
- [ ] Varsa şirket/vergi kayıt bilgisi
- [ ] Kullanım koşulları için uygulanacak hukuk ve yetkili mahkeme
- [ ] Çocuklara yönelik minimum yaş/ülke stratejisinin hukuk danışmanıyla onayı

## Domain ve mağaza

- [ ] Pinly'ye ait doğrulanmış production domain
- [ ] Domain sahipliği ve marka çakışması kontrolü
- [ ] App Store uygulama kimliği ve resmi ürün sayfası URL'si
- [ ] App Store Connect Support URL, Marketing URL ve Privacy Policy URL
- [ ] Universal Link/App Site Association kapsamı (kullanılacaksa)
- [ ] Canonical, `og:url` ve mutlak `og:image` kök adresi

> `https://pinly.app` şu anda bu projeye ait olduğu doğrulanmış bir domain değildir. Uygulama veya metadata bu adrese bağlanmamalıdır.

## Hukuk ve gizlilik

- [ ] Gizlilik Politikası yürürlük tarihi
- [ ] Kullanım Koşulları yürürlük tarihi
- [ ] Destek yanıt süresi taahhüdü
- [ ] AB/AEA, Birleşik Krallık, Türkiye ve ABD eyaletleri için dağıtım kapsamı
- [ ] Veri sorumlusu/işleyen rolleri ve uluslararası aktarım metni hukuk kontrolü
- [ ] App Store Privacy Nutrition Label cevapları
- [ ] Google UMP mesajı ve privacy options entry point testi
- [ ] Firebase, Crashlytics, AdMob ve RevenueCat veri saklama ayarlarının dashboard doğrulaması
- [ ] Website analytics/cookie kullanılıp kullanılmayacağı (mevcut statik site analytics/cookie kullanmıyor)

## Yayın kapısı

Bu bilgiler tamamlanmadan:

1. `landing/**/index.html` dosyalarındaki `data-release-ready="false"` kaldırılmamalı.
2. Taslak uyarıları ve `noindex` etiketleri kaldırılmamalı.
3. `PinlyLegal` production URL'leriyle doldurulmamalı.
4. Website deploy edilmemeli ve App Store metadata'sına URL girilmemeli.
