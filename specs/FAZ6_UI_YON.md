# FAZ 6 — UI Yön Belgesi (Fable) — wow mimarileri + Sonnet'e giden basit işler

## Kimlik kararı
Seigaiha paleti DEĞİŞMEZ (krem/kağıt + sage + toz mavi-gri + lacivert). Trend "beyaz minimal"e
yaklaşmak YOK — ayrıştırıcımız bu. Tüm yeni renk kullanımı `PinlyTheme` token'larından.

## Liquid Glass stratejisi (iOS 26) — Fable mimarisi
- Hedef iOS 17 KALIR. Tüm glass kullanımı `if #available(iOS 26.0, *)` + fallback mevcut görünüm.
- Merkezi kapı: `View.pinlyGlass(_ shape:)` modifier'ı (Theme.swift'e) — available'sa `glassEffect`,
  değilse mevcut `.pinlyCard()`/material. Görünüm dağınık if-else'e BOĞULMAZ, tek modifier.
- UYGULANACAK yerler (sadece harita/foto ÜSTÜNDE yüzen katmanlar — cam, altında içerik varken anlamlı):
  1. PinlyTabBar (gooey varyantın glass sürümü — navy zemin korunur, cam sadece highlight)
  2. RouteSummaryView NavigationBanner + RouteOverviewPanel (harita üstü)
  3. Keşfet çekilebilir panel tutamacı/başlığı
- UYGULANMAYACAK: form ekranları, liste satırları, paywall (okunabilirlik + ciddiyet).
- Metin kontrastı: cam üstünde `PinlyTheme.navy` yazı + `.bold()` — soluk gri yazı cam üstünde ölür.

## Wow #1 — Rota tamamlama sekansı (Fable koreografisi; uygulaması Sonnet)
Sıra: konfeti (var) → istatistiklerin SIRAYLA gelişi (km → dk → adım, her biri 0.15 sn arayla
spring + `contentTransition(.numericText())` ile 0'dan sayarak) → 0.6 sn sonra hikaye kartı
alttan `spring(response: 0.55, dampingFraction: 0.75)` ile yükselir, hafif 3D `rotation3DEffect`
(-8°→0°) "masaya kart koyma" hissi → success haptic çifti (`.success` + 0.1 sn sonra hafif `.impact(.soft)`).
Reduce Motion açıksa: sayaçlar animasyonsuz, kart fade — `@Environment(\.accessibilityReduceMotion)`.

## Wow #2 — Kart→detay geçişleri (Fable mimarisi — DİKKAT: tuzaklı)
- `matchedGeometryEffect` **fullScreenCover/sheet SINIRINDAN GEÇMEZ** (bilinen SwiftUI kısıtı).
  Karar: iOS 18+ `navigationTransition(.zoom(sourceID:in:))` kullan (Keşfet kartı → rota detayı,
  Günlük kartı → MemoryDetailView). iOS 17 fallback: varsayılan push. `#available(iOS 18.0, *)`.
- `matchedGeometryEffect` SADECE aynı hiyerarşi içinde: kategori chip seçimi, tab bar gooey blob,
  paywall plan seçim vurgusu.

## Wow #3-6 (Sonnet — spec net, riski düşük)
- Harita pin drop: `scaleEffect` 0→1.1→1 spring + seçili pin "nefes" (1.0↔1.06, 2 sn, `repeatForever`;
  navigasyon pulse'ıyla AYNI kod yolu — NavigationMapView'deki mevcut pulse'ı yeniden kullan)
- Keşfet kartlarında `scrollTransition`: hafif `opacity(0.85→1)` + `scale(0.96→1)` — parallax ABARTMA
- Haptic haritası (tek merkez `HapticPlayer` yardımcısı, UIKit generator'ları önceden hazırlar):
  durak varışı `.success` · rozet `.success`+`.impact(.rigid)` · fav `.impact(.light)` ·
  seçim toggle `.selection` · rota başlat `.impact(.medium)`
- Onboarding canlı dalga: `TimelineView(.animation)` + `WavePattern` faz kaydırması (yalnızca
  onboarding'de; pil için 30 fps sınırı `.animation(minimumInterval: 1/30)`)
- Sayısal her yerde `contentTransition(.numericText())`: StatChip'ler, profil istatistikleri, fav sayacı

## Boş durumlar (Sonnet)
SF Symbol yerine `WavePattern` dilinde mini vektör sahneler: 2-3 katmanlı dalga + tek vurgu ögesi
(pin/pusula/kart), hepsi `Shape` tabanlı (raster YOK — mevcut karar korunur). Ekranlar: Günlük boş,
Keşfet konum kapalı, Rotalar boş (mevcut WavePattern kullanımı referans).

## Erişilebilirlik kapısı (her PR'da)
Dynamic Type XL'de kırılmama, kontrast ≥ 4.5:1 (cam üstü dahil), Reduce Motion yolları,
VoiceOver: yeni butonlarda label.

## Sıralama
1. Wow #1 (tamamlama sekansı — FAZ 3 hikaye kartıyla birlikte çıkar, en yüksek his/emek oranı)
2. Haptic haritası + numericText (yarım gün, her yere yayılır)
3. Wow #2 zoom geçişleri → 4. pin/scroll animasyonları → 5. Liquid Glass → 6. boş durumlar
