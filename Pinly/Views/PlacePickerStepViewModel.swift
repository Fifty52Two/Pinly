import Foundation
import CoreLocation

// MARK: - PlacePickerStepViewModel
//
// PlacePickerStepView'ın rota-kategori seçim adımındaki iş mantığı: mevcut
// kategori/mekan listesi türetme ve seçim yazımı. Durumsuz — tüm bağımlılıklar
// (RouteNavigationTracking, PlaceRepository) zaten View'da environment'tan
// enjekte edilmiş olduğu için metodlara parametre olarak geçirilir.

@MainActor
final class PlacePickerStepViewModel: ObservableObject {
    func currentCategory(stepIndex: Int, tracker: RouteNavigationTracking) -> String {
        guard stepIndex < tracker.selectedCategories.count else { return "" }
        return tracker.selectedCategories[stepIndex]
    }

    func availablePlaces(category: String, placeStore: PlaceRepository, userLocation: CLLocation?, radiusKm: Double) -> [Place] {
        placeStore.places(category: category, userLocation: userLocation, radiusKm: radiusKm)
    }

    func isLastStep(stepIndex: Int, tracker: RouteNavigationTracking) -> Bool {
        stepIndex == tracker.selectedCategories.count - 1
    }

    func radiusLabel(_ radiusKm: Double) -> String {
        radiusKm == 0 ? NSLocalizedString("Tümü", comment: "") : "\(Int(radiusKm)) km"
    }

    /// Aynı kategoriden birden fazla mekan seçilebilir — seçiliyse çıkarır,
    /// değilse SIRAYI koruyarak sona ekler (rota sırası = seçim sırası).
    func togglePlace(_ place: Place, category: String, tracker: RouteNavigationTracking) {
        var current = tracker.selectedPlaces[category] ?? []
        if let idx = current.firstIndex(where: { $0.id == place.id }) {
            current.remove(at: idx)
        } else {
            current.append(place)
        }
        tracker.selectedPlaces[category] = current
    }

    func isSelected(_ place: Place, category: String, tracker: RouteNavigationTracking) -> Bool {
        tracker.selectedPlaces[category]?.contains(where: { $0.id == place.id }) ?? false
    }

    func selectionCount(category: String, tracker: RouteNavigationTracking) -> Int {
        tracker.selectedPlaces[category]?.count ?? 0
    }
}
