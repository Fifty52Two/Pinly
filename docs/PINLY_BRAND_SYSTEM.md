# Pinly Brand System

Kaynak: `Pinly/Design/Theme.swift`, `Pinly/Design/WavePattern.swift`, gerçek app iconu ve production SwiftUI ekranları. Bu belge yeni bir marka önermiyor; uygulamadaki sistemi web/metadata için çıkarıyor.

## Öz

Pinly'nin görsel dili: **kağıt zemin + toz mavi-gri + sage + terracotta + seigaiha + organik dalgalar + hairline kartlar**.

Ton: sakin, kişisel, şehirli ve eyleme dönük. “Harita SaaS'ı”, sosyal ağ veya neon teknoloji ürünü gibi görünmemeli.

Ana mesaj:

> Kaydetme. Git.

Ürün döngüsü:

> Pinle → Planla → Yürü → Hatırla

## Renk tokenları

| Token | Light | Dark | Kullanım |
|---|---:|---:|---|
| Ground | `#F0E9DC` | `#1C1A22` | Ana kağıt/sayfa zemini |
| Surface | `#F7F2E8` | `#2E2A38` | Kart ve yükseltilmemiş yüzey |
| Primary | `#42505E` | `#9DB0C2` | Birincil CTA, aktif rota, ana vurgu |
| Primary Warm | `#748496` | `#B4C4D2` | İkincil rota/çizgi, daha hafif vurgu |
| Terracotta | `#B5533F` | `#D97A62` | Yolculuk/eylem/kutlama aksanı |
| Sage | `#5A6E54` | `#9BAF93` | Tamamlanan rota, başarı, doğal bölüm |
| Gold | `#A88B4A` | `#C9AD6E` | Rozet, puan, ölçülü premium aksan |
| Navy | `#221E2B` | sabit | Her modda koyu kalan anlatı yüzeyi |

Web karşılığı `landing/assets/site.css` içindeki `--pinly-*` değişkenleridir. Uygulama değişirse web tokenları ayrıca güncellenmelidir.

## Şekil ve yüzey

- Kart yarıçapı: yaklaşık 16 pt/px.
- Birincil buton yarıçapı: yaklaşık 14 pt/px.
- Kartlarda gölge yerine 1 px düşük opaklıklı hairline kullanılır.
- Büyük hero veya cihaz sunumu gölge kullanabilir; kartlar generic SaaS gölgesine dönmez.
- App iconu terracotta zemin üzerindeki krem rota düğümleridir; web logosu aynı gerçek asset'i kullanır.

## Desen ailesi

### Seigaiha

İç içe yarım daire dalgaları Pinly'nin ana dokusudur. Web native vector mask kullanır: `landing/assets/seigaiha-mask.svg`. Hero, Pro, legal masthead ve seçili atmosfer alanlarında düşük opaklıkta kullanılır. Metin kontrastının önüne geçmez.

### WavePattern

SwiftUI'daki yuvarlanan yatay hareketin web yorumu `landing/assets/wave-mask.svg` dosyasıdır. Scroll story ve footer atmosferinde kullanılır. Rasterleştirilmez.

### WavyHorizon

Krem ile sage/navy sahneler arasındaki düzensiz sınırdır. Homepage hero çıkışında native inline SVG ile kullanılır. Düz, jenerik dikdörtgen bölüm geçişlerinin yerini yalnız 2–4 önemli noktada almalıdır.

## Tipografi ve ikon

- Apple platformunda sistem fontları kullanılır; sahte Apple font dosyası taşınmaz.
- Başlıklar sıkı harf aralığı ve güçlü ağırlıkla kısa tutulur.
- Arayüz ikonları uygulamada SF Symbols, webde tutarlı strok SVG ailesidir.
- Emoji ürün ikonu olarak kullanılmaz.

## Hareket

- Route line draw, pin görünümü, yumuşak reveal ve screenshot ölçek/crossfade ölçülüdür.
- Scroll hijacking, sahte momentum, cursor efekti, autoplay video ve büyük animasyon bağımlılığı yoktur.
- `prefers-reduced-motion: reduce` durumunda bilgi aynı kalır; route çizimi ve reveal anında son durumu gösterir.

## Fotoğraf ve ekran kuralları

- Yalnız gerçek app UI kullanılır.
- Sahte Dynamic Island, uydurma rota veya mock paywall üretilmez.
- Kişisel mekan, adres, isim, e-posta, fotoğraf, test reklamı ve debug etiketi yayınlanmaz.
- Mevcut doğrulanmış assetler yalnız Home TR/EN'dir. Diğer ürün sahneleri `docs/SCREENSHOT_REQUIREMENTS.md` tamamlanana kadar release blocker'dır.

## Kaçınılacaklar

- Neon/purple “AI” gradientleri.
- Glassmorphism'i varsayılan yüzey dili yapmak.
- Büyük bulanık kart gölgeleri.
- Apple'ın sayfa yapısını, cihaz artwork'ünü veya animasyon zamanlarını kopyalamak.
- “100% private”, “hiç veri toplamıyoruz” veya kodla kanıtlanmayan pazarlama iddiaları.
