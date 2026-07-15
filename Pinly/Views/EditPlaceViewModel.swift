import Foundation
import CoreLocation
import SwiftData

// MARK: - EditPlaceViewModel

final class EditPlaceViewModel: PlaceFormViewModel {
    let place: Place

    init(place: Place,
         geocoding: GeocodingProviding = DefaultGeocodingService.shared,
         photoStore: PlacePhotoStoring = DefaultPlacePhotoStore.shared) {
        self.place = place
        super.init(
            name: place.name,
            category: place.category,
            address: place.address,
            notes: place.notes,
            geocoding: geocoding,
            photoStore: photoStore
        )
        // Mevcut fotoğrafı forma yükle (photoChanged false kalır)
        photoImage = place.photoFileName.flatMap { photoStore.load(fileName: $0) }
    }

    func save(placeStore: PlaceRepository, context: ModelContext) async {
        isSaving = true
        let addressChanged = address != place.address && !address.isEmpty

        place.name = name
        place.category = category
        place.notes = notes

        if usedCurrentLocation, let coord = currentCoord {
            place.latitude = coord.latitude
            place.longitude = coord.longitude
            place.address = "Mevcut Konum"
            place.locationName = "Mevcut Konum"
        } else if let coord = pinnedCoord {
            // Haritadan pinlenen koordinat — geocode atlanır
            place.latitude = coord.latitude
            place.longitude = coord.longitude
            place.address = address
            place.locationName = address
        } else if addressChanged {
            place.address = address
            if let coord = await geocode(name: name, address: address) {
                place.latitude = coord.latitude
                place.longitude = coord.longitude
            }
        }

        persistPhoto(to: place)
        placeStore.save(context: context)
        placeStore.load(context: context)
        isSaving = false
    }

    private func geocode(name: String, address: String) async -> CLLocationCoordinate2D? {
        if let coord = await geocoding.forwardGeocode(query: "\(name) \(address)") {
            return coord
        }
        return await geocoding.forwardGeocode(query: address)
    }
}
