import Foundation
import SwiftData

// MARK: - AddPlaceViewModel

final class AddPlaceViewModel: PlaceFormViewModel {
    func save(placeStore: PlaceRepository, context: ModelContext) async {
        isSaving = true
        if usedCurrentLocation, let coord = currentCoord {
            let place = Place(name: name, category: category, address: "Mevcut Konum", notes: notes)
            place.latitude = coord.latitude
            place.longitude = coord.longitude
            place.locationName = "Mevcut Konum"
            context.insert(place)
            placeStore.save(context: context)
            placeStore.load(context: context)
        } else {
            // Haritadan pinlendiyse koordinat direkt kullanılır, geocode atlanır
            await placeStore.addPlace(
                name: name,
                category: category,
                address: address,
                notes: notes,
                coordinate: pinnedCoord,
                context: context
            )
        }
        isSaving = false
    }
}
