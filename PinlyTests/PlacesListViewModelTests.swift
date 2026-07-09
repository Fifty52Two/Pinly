import XCTest
import CoreLocation
@testable import Pinly

@MainActor
final class PlacesListViewModelTests: XCTestCase {
    private func makeViewModel(suiteName: String) -> PlacesListViewModel {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PlacesListViewModel(defaults: defaults)
    }

    func test_sortedPlaces_byDistance_ordersCorrectly() {
        let vm = makeViewModel(suiteName: #function)
        vm.setSortOption(.distance)

        let near = Place(name: "Near")
        near.latitude = 41.0; near.longitude = 29.0
        let far = Place(name: "Far")
        far.latitude = 42.0; far.longitude = 30.0

        let userLoc = CLLocation(latitude: 41.0, longitude: 29.0)
        let sorted = vm.sortedPlaces([far, near], userLocation: userLoc)

        XCTAssertEqual(sorted.map(\.name), ["Near", "Far"])
    }

    func test_filteredPlaces_appliesSearchTextAndCategory() {
        let vm = makeViewModel(suiteName: #function)
        let cafe = Place(name: "Coffee House", category: PlaceCategory.cafe.rawValue)
        let restaurant = Place(name: "Kebab House", category: PlaceCategory.restaurant.rawValue)

        vm.selectedCategory = .cafe
        let byCategory = vm.filteredPlaces([cafe, restaurant], userLocation: nil)
        XCTAssertEqual(byCategory.map(\.name), ["Coffee House"])

        vm.selectedCategory = nil
        vm.searchText = "kebab"
        let bySearch = vm.filteredPlaces([cafe, restaurant], userLocation: nil)
        XCTAssertEqual(bySearch.map(\.name), ["Kebab House"])
    }

    func test_setSortOption_persistsToUserDefaults() {
        let suiteName = #function
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let vm = PlacesListViewModel(defaults: defaults)
        vm.setSortOption(.alphabetical)

        XCTAssertEqual(defaults.string(forKey: "pinly.sortOption"), PlaceSortOption.alphabetical.rawValue)

        let reloaded = PlacesListViewModel(defaults: defaults)
        XCTAssertEqual(reloaded.sortOption, .alphabetical)
    }

    func test_clearFilters_resetsSearchAndCategory() {
        let vm = makeViewModel(suiteName: #function)
        vm.searchText = "test"
        vm.selectedCategory = .park
        vm.clearFilters()
        XCTAssertEqual(vm.searchText, "")
        XCTAssertNil(vm.selectedCategory)
    }
}
