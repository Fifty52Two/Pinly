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

    func selectPlace(_ place: Place, category: String, tracker: RouteNavigationTracking) {
        tracker.selectedPlaces[category] = place
    }
}
