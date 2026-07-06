import Foundation
import CoreLocation

// MARK: - Mekan Listesi ViewModel
//
// Arama / kategori filtresi / sıralama mantığı view'dan ayrıldı (SRP).
// Saf fonksiyonlar girdi olarak places + userLocation alır; böylece
// PlaceStore veya LocationManager'a bağımlılık olmadan test edilebilir.

@MainActor
final class PlacesListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCategory: PlaceCategory? = nil
    @Published private(set) var sortOption: PlaceSortOption

    private static let sortOptionKey = "pinly.sortOption"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.sortOptionKey) ?? PlaceSortOption.dateAdded.rawValue
        self.sortOption = PlaceSortOption(rawValue: raw) ?? .dateAdded
    }

    func setSortOption(_ option: PlaceSortOption) {
        sortOption = option
        defaults.set(option.rawValue, forKey: Self.sortOptionKey)
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
    }

    func sortedPlaces(_ places: [Place], userLocation: CLLocation?) -> [Place] {
        switch sortOption {
        case .dateAdded:
            return places.sorted { $0.createdAt > $1.createdAt }
        case .alphabetical:
            return places.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .distance:
            guard let userLoc = userLocation else {
                return places.sorted { $0.createdAt > $1.createdAt }
            }
            return places.sorted { a, b in
                guard let coordA = a.coordinate, let coordB = b.coordinate else { return false }
                let locA = CLLocation(latitude: coordA.latitude, longitude: coordA.longitude)
                let locB = CLLocation(latitude: coordB.latitude, longitude: coordB.longitude)
                return userLoc.distance(from: locA) < userLoc.distance(from: locB)
            }
        case .visitCount:
            return places.sorted { $0.visitCount > $1.visitCount }
        }
    }

    func filteredPlaces(_ places: [Place], userLocation: CLLocation?) -> [Place] {
        var result = sortedPlaces(places, userLocation: userLocation)
        if let cat = selectedCategory {
            result = result.filter { PlaceCategory.from($0.category) == cat }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                $0.address.lowercased().contains(q)
            }
        }
        return result
    }
}
