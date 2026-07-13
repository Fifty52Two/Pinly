import XCTest
import SwiftData
@testable import Pinly

@MainActor
final class PlaceStoreMigrationTests: XCTestCase {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Place.self, RouteHistory.self, SavedRoute.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func test_load_migratesLegacyTurkishCategoryToCanonicalRawValue() {
        let context = makeInMemoryContext()
        let legacyPlace = Place(name: "Eski Kayıt", category: "müze")
        context.insert(legacyPlace)
        try? context.save()

        let store = PlaceStore()
        store.load(context: context)

        XCTAssertEqual(store.places.first?.category, PlaceCategory.museum.rawValue)
    }

    func test_load_canonicalCategory_isUntouched() {
        let context = makeInMemoryContext()
        let place = Place(name: "Yeni Kayıt", category: PlaceCategory.park.rawValue)
        context.insert(place)
        try? context.save()

        let store = PlaceStore()
        store.load(context: context)

        XCTAssertEqual(store.places.first?.category, PlaceCategory.park.rawValue)
    }

    func test_load_isIdempotent_secondLoadDoesNotChangeAlreadyMigratedCategory() {
        let context = makeInMemoryContext()
        let legacyPlace = Place(name: "Eski Kayıt", category: "restoran")
        context.insert(legacyPlace)
        try? context.save()

        let store = PlaceStore()
        store.load(context: context)
        let afterFirstLoad = store.places.first?.category

        store.load(context: context)
        let afterSecondLoad = store.places.first?.category

        XCTAssertEqual(afterFirstLoad, PlaceCategory.restaurant.rawValue)
        XCTAssertEqual(afterSecondLoad, PlaceCategory.restaurant.rawValue)
    }
}
