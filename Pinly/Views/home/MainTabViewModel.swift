import Foundation

// MARK: - MainTabViewModel
//
// MainTab'ın (ana ekran) iş mantığı: saate göre selamlama, ziyaret sayısı,
// son eklenen mekanlar. Durumsuz — girdi olarak places alır, PlaceStore'a
// bağımlılık olmadan test edilebilir.

@MainActor
final class MainTabViewModel: ObservableObject {
    /// Saate göre selamlama metni + eşlik eden SF Symbol adı.
    /// Emoji yerine sembol dönmesi bilinçli — arayüzde emoji kullanılmaz (tasarım kuralı).
    func greeting() -> (text: String, symbol: String) {
        switch Calendar.current.component(.hour, from: Date()) {
        case 6..<12:  return (NSLocalizedString("Günaydın", comment: ""), "sun.max.fill")
        case 12..<18: return (NSLocalizedString("İyi günler", comment: ""), "hand.wave.fill")
        case 18..<23: return (NSLocalizedString("İyi akşamlar", comment: ""), "sunset.fill")
        default:      return (NSLocalizedString("İyi geceler", comment: ""), "moon.stars.fill")
        }
    }

    func visitedCount(_ places: [Place]) -> Int {
        places.filter { $0.isVisited }.count
    }

    func recentPlaces(_ places: [Place]) -> [Place] {
        Array(places.sorted { $0.createdAt > $1.createdAt }.prefix(6))
    }
}
