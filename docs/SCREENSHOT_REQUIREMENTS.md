# Pinly Release Screenshot Requirements

Durum: yalnız TR/EN Home ekranı doğrulandı. Diğer sahneler üretilmeden website/App Store screenshot alanı `BLOCKED BY USER` kalır.

## Kaynak kuralları

- Aynı Release Candidate build'i ve temiz, inandırıcı demo verisi kullanılmalı.
- Gerçek app UI; sahte Dynamic Island, uydurma rota, mock navigation veya tasarım dosyası yok.
- Kişisel isim, özel mekan/adres/not/fotoğraf, test e-postası, debug label, test reklamı ve cihaz bildirimi görünmemeli.
- Kullanıcı her görüntüyü yayın öncesi ayrıca incelemeli.
- TR ve EN için aynı ürün hikâyesi korunmalı.

## Gerekli ürün sahneleri

| # | Sahne | Beklenen kanıt | App Store mesajı |
|---:|---|---|---|
| 1 | Home / saved places | Home + anlamlı demo mekanları | Kaydetme. Git. |
| 2 | Discover / Nearby | Gerçek arama sonucu, kişisel konum ifşa etmeden | Yakınındaki yeni durakları bul. |
| 3 | Route creation | Çoklu durak + rota sırası | Mekanlarını bir güne dönüştür. |
| 4 | Route summary | Mesafe/duraklar ve start CTA | Yola çıkmadan önce planını gör. |
| 5 | Active navigation | Gerçek yürüyüş/navigation UI | Adım adım yürü. |
| 6 | Live Activity | Simulator/device gerçekten destekliyorsa | Sıradaki durağın hep yanında. |
| 7 | Completion / memory | Gerçek tamamlanmış rota ve izinli stats | Gezdiğin günü hatırla. |
| 8 | GPX/PDF Pro | Gerçek export gate/başarılı share sheet | Dışa aktar. |
| 9 | Paywall | App Store/RevenueCat localized fiyat, uygun trial durumu | Pinly Pro. |

## App Store sırası

1. Kaydetme. Git.
2. Mekanlarını bir güne dönüştür.
3. Adım adım yürü.
4. Sıradaki durağın hep yanında.
5. Gezdiğin günü hatırla.
6. Swarm geçmişini yanında getir.
7. Dışa aktar.

## Kayıt tablosu

Her satır için dosya yolu, build numarası, cihaz/simulator, dil, tarih ve kullanıcı onayı eklenmelidir. Boş satır PASS değildir.
