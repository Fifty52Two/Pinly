# Pinly V1 — Accessibility Audit

Son güncelleme: 25 Ağustos 2026.

## Kod ve web taraması

Status: **IN PROGRESS** — statik kontroller ve web keyboard/reduced-motion QA tamamlandı; gerçek cihaz VoiceOver/Dynamic Type kanıtı kullanıcıda bekliyor.

- Ana SwiftUI akışları sistem `Text`, `Button`, `NavigationStack`, `List`/`ScrollView` semantiğini kullanıyor.
- Home, Discover, Places, route banner/completion, memories ve tab bar içinde birleşik/özel VoiceOver etiketleri mevcut.
- Yakınımda radius/map-list/refresh; harita back/add ve place-card share/edit/delete/close; mekan detail share/edit; saved-route add; route-flow/history ve Weekly/Badges close ikonlarına açık erişilebilir ad eklendi.
- Canlı harita place-card üzerindeki dört küçük ikon kontrolü en az 44×44 pt hit area alır.
- Harita üzerindeki özel yuvarlak eylemler padding ile yaklaşık 44 pt hedefe ulaşıyor. Toolbar kontrollerinin hit area yönetimi sistemde.
- Anlam taşımayan yardımcı ikonların önemli kartlarda `accessibilityHidden(true)` ile tekrar okuma üretmesi engellenmiş.
- Web'de semantic `nav`, `main`, `section`, `footer`, görünür focus ring ve tek bir H1 var.
- Web animasyonları `prefers-reduced-motion: reduce` altında son duruma geçiyor; scroll-story içerik erişilebilir olmaya devam ediyor.
- Web 320, 375, 390, 430, 768, 1024 ve 1440 px genişliklerinde yatay taşma üretmedi.

## Release cihaz matrisi

Aşağıdakiler aynı RC build numarasıyla `DEVICE_QA.md` içine kanıt olarak yazılmadan PASS verilmez:

1. VoiceOver ile onboarding → ilk mekan → rota oluştur → rota başlat/bitir → paylaş.
2. Dynamic Type `AX1`, `AX3` ve en büyük erişilebilirlik boyutunda kesilme/örtüşme kontrolü.
3. Reduce Motion açıkken onboarding, rota tamamlama ve badge animasyonları.
4. Increase Contrast, Reduce Transparency ve Button Shapes açıkken CTA ayrımı.
5. Light Appearance ve uygulamanın desteklediği ekran görünümü; kritik metin/zemin kontrastı.
6. Switch Control veya Full Keyboard Access ile temel navigation.

## Bilinçli V1 sınırı

Uygulama composition root'u halen light appearance uygular; web sistem dark mode'u destekler. Uygulama dark mode'u cihaz QA yapılmadan sessizce açılmayacak. Bu bir erişilebilirlik iddiası değil, doğrulanmamış görünümün release'e sokulmaması için kapsam sınırıdır.
