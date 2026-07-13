import Foundation

// MARK: - MainTabViewModel
//
// MainTab'ın (ana ekran) iş mantığı: saate göre selamlama, ziyaret sayısı,
// son eklenen mekanlar. Durumsuz — girdi olarak places alır, PlaceStore'a
// bağımlılık olmadan test edilebilir.

@MainActor
final class MainTabViewModel: ObservableObject {
    func greeting() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 6..<12:  return NSLocalizedString("Günaydın ☀️", comment: "")
        case 12..<18: return NSLocalizedString("İyi günler 👋", comment: "")
        case 18..<23: return NSLocalizedString("İyi akşamlar 🌆", comment: "")
        default:      return NSLocalizedString("İyi geceler 🌙", comment: "")
        }
    }

    func visitedCount(_ places: [Place]) -> Int {
        places.filter { $0.isVisited }.count
    }

    func recentPlaces(_ places: [Place]) -> [Place] {
        Array(places.sorted { $0.createdAt > $1.createdAt }.prefix(6))
    }
}
