# Pinly Website QA

Son repo-içi test: 25 Ağustos 2026. Test yüzeyi: `landing/`, localhost; production hosting testi değildir.

## Otomatik/araç destekli kanıt

| Kontrol | Status | Evidence |
|---|---|---|
| TR homepage load | PASS | Başlık `Pinly — Kaydetme. Git.`, H1 görünür, console error yok. |
| EN homepage load | PASS | Başlık ve `Don’t save it. Go.` H1 görünür, console error yok. |
| Responsive overflow | PASS | 320, 375, 390, 430, 768, 1024 ve 1440 px genişliklerde `scrollWidth == innerWidth`. |
| Semantic landmarks | PASS | Homepage/legal: tek `nav`, `main`, `footer`; skip link ve heading düzeni mevcut. |
| Real image load | PASS | Gerçek TR/EN simulator PNG'leri ve gerçek app iconu doğal genişlikle yükleniyor. |
| Scroll story | PASS | CSS sticky desktop'ta aktif; dört narrative step IntersectionObserver ile değişiyor. |
| Reduced motion implementation | PASS | Media query reveal/route animation/transform hareketlerini son duruma getiriyor. |
| Legal draft guard | PASS | `data-release-ready=false`, `noindex,nofollow` ve draft uyarıları korunuyor. |
| 404 | PASS | `landing/404.html` Pinly dilinde, noindex ve ana sayfa/destek yollarıyla mevcut. |
| Robots | PASS | Domain/legal hazır olmadığı için `Disallow: /`; yorum release değişikliğini açıklıyor. |
| Local route crawl | PASS | `/`, `/en/`, 8 legal/support rotası, `/404.html` ve `/robots.txt` localhost'ta HTTP 200. |

## Görsel sistem kanıtı

- Tokenlar `Theme.swift` ile aynı light/dark renklerden türetilir.
- App iconu doğrudan asset catalog kaynağından alınmıştır.
- Seigaiha ve Wave native SVG mask; raster SwiftUI kopyası değildir.
- Kartlar 16 px hairline, butonlar 14 px ve minimal shadow kullanır.
- Homepage'te organik WavyHorizon ve uygulama screenshot'lı sticky hikâye vardır.
- Emoji ikon yerine aynı strok dilinde inline SVG kullanılır.

## Production öncesi BLOCKED

- Safari ve gerçek iPhone WebKit smoke.
- Chrome production smoke.
- Keyboard-only tam tur, VoiceOver/screen reader ve 200% zoom manuel kanıtı.
- Lighthouse hedefleri: Performance 90+, Accessibility 95+, Best Practices 95+, SEO 95+.
- Gerçek HTTPS/domain, canonical, hreflang, absolute OpenGraph URL/image ve sitemap.
- App Store badge/Smart App Banner ve resmî product URL.
- Legal/support iletişim değerleri; `robots.txt` release modu.

Bu maddeler tamamlanmadan website release-ready değildir.
