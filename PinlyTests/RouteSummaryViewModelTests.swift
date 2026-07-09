import XCTest
import CoreLocation
import SwiftData
@testable import Pinly

@MainActor
final class RouteSummaryViewModelTests: XCTestCase {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Place.self, RouteHistory.self, SavedRoute.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeViewModel(badges: MockBadgeServicing? = nil) -> RouteSummaryViewModel {
        RouteSummaryViewModel(
            badges: badges ?? MockBadgeServicing(),
            entitlements: MockEntitlementProviding(),
            ads: MockAdPresenting(),
            healthStats: MockHealthStatsProviding(),
            savedRoutes: MockSavedRouteRepository(),
            routeExporter: MockRouteExporting()
        )
    }

    func test_addNoteToCurrentStop_appendsToExistingNotes() {
        let vm = makeViewModel()
        let place = Place(name: "Cafe", notes: "existing")
        let repository = MockPlaceRepository()
        let context = makeInMemoryContext()

        vm.stopNote = "new note"
        let didAdd = vm.addNoteToCurrentStop(routePlaces: [place], currentWaypointIndex: 0, context: context, placeStore: repository)

        XCTAssertTrue(didAdd)
        XCTAssertEqual(place.notes, "existing\n• new note")
        XCTAssertEqual(vm.stopNote, "")
    }

    func test_addNoteToCurrentStop_emptyNote_doesNothing() {
        let vm = makeViewModel()
        let place = Place(name: "Cafe")
        let repository = MockPlaceRepository()
        let context = makeInMemoryContext()

        vm.stopNote = "   "
        let didAdd = vm.addNoteToCurrentStop(routePlaces: [place], currentWaypointIndex: 0, context: context, placeStore: repository)

        XCTAssertFalse(didAdd)
    }

    func test_handleArrival_marksPlaceVisitedAndIncrementsCount() {
        let vm = makeViewModel()
        let place = Place(name: "Museum")
        let repository = MockPlaceRepository()
        let context = makeInMemoryContext()

        vm.handleArrival(place: place, context: context, placeStore: repository)

        XCTAssertTrue(place.isVisited)
        XCTAssertEqual(place.visitCount, 1)
        XCTAssertEqual(vm.arrivedPlaceName, "Museum")
        XCTAssertEqual(vm.pendingRatingPlace?.id, place.id)
    }

    func test_recordRouteShared_recordsBadgeAndReturnsNewlyUnlocked() {
        let badges = MockBadgeServicing()
        badges.badgesToUnlockOnCheck = [.paylasimci]
        let vm = makeViewModel(badges: badges)
        let repository = MockPlaceRepository()

        let newBadges = vm.recordRouteShared(placeStore: repository)

        XCTAssertEqual(badges.sharedRouteCount, 1)
        XCTAssertEqual(newBadges, [.paylasimci])
    }

    func test_saveRoute_recordsBadgeAndReturnsNewlyUnlocked() {
        let badges = MockBadgeServicing()
        badges.badgesToUnlockOnCheck = [.planlamaci]
        let vm = makeViewModel(badges: badges)
        let repository = MockPlaceRepository()
        let context = makeInMemoryContext()
        let place = Place(name: "A")

        let newBadges = vm.saveRoute(name: "My Route", category: .city, places: [place], context: context, placeStore: repository)

        XCTAssertEqual(badges.savedRouteCount, 1)
        XCTAssertEqual(newBadges, [.planlamaci])
    }

    func test_exportRouteName_prefersShareRouteName() {
        let vm = makeViewModel()
        vm.shareRouteName = "Kadıköy Turu"
        XCTAssertEqual(vm.exportRouteName(fallbackRouteName: "Fallback"), "Kadıköy Turu")

        vm.shareRouteName = ""
        XCTAssertEqual(vm.exportRouteName(fallbackRouteName: "Fallback"), "Fallback")
    }
}
