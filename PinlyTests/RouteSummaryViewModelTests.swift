import XCTest
import CoreLocation
import SwiftData
import UIKit
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

    private func makeViewModel(
        badges: MockBadgeServicing? = nil,
        entitlements: MockEntitlementProviding? = nil,
        analytics: MockAnalyticsTracking? = nil,
        routeMemories: MockRouteMemoryStoring? = nil,
        memoryCards: MockMemoryCardComposing? = nil,
        placePhotos: MockPlacePhotoStoring? = nil
    ) -> RouteSummaryViewModel {
        RouteSummaryViewModel(
            badges: badges ?? MockBadgeServicing(),
            entitlements: entitlements ?? MockEntitlementProviding(),
            ads: MockAdPresenting(),
            healthStats: MockHealthStatsProviding(),
            savedRoutes: MockSavedRouteRepository(),
            routeExporter: MockRouteExporting(),
            analytics: analytics ?? MockAnalyticsTracking(),
            routeMemories: routeMemories ?? MockRouteMemoryStoring(),
            memoryCards: memoryCards ?? MockMemoryCardComposing(),
            placePhotos: placePhotos ?? MockPlacePhotoStoring()
        )
    }

    private func makeEphemeralDefaults() -> UserDefaults {
        let suite = "test.softPaywall.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Soft Paywall (tek seferlik hak)

    func test_consumeSoftPaywallOffer_firstCall_returnsTrueAndBurnsFlag() {
        let vm = makeViewModel()
        let defaults = makeEphemeralDefaults()

        XCTAssertTrue(vm.consumeSoftPaywallOffer(defaults: defaults))
        XCTAssertTrue(defaults.bool(forKey: "pinly.softPaywallShown"))
    }

    func test_consumeSoftPaywallOffer_secondCall_returnsFalse() {
        let vm = makeViewModel()
        let defaults = makeEphemeralDefaults()

        _ = vm.consumeSoftPaywallOffer(defaults: defaults)
        XCTAssertFalse(vm.consumeSoftPaywallOffer(defaults: defaults))
    }

    func test_consumeSoftPaywallOffer_proUser_returnsFalse_andFlagStaysUnset() {
        let pro = MockEntitlementProviding()
        pro.isPro = true
        let vm = makeViewModel(entitlements: pro)
        let defaults = makeEphemeralDefaults()

        XCTAssertFalse(vm.consumeSoftPaywallOffer(defaults: defaults))
        // Pro kullanıcıda hak YAKILMAZ — abonelik biterse ileride hâlâ gösterilebilir
        XCTAssertFalse(defaults.bool(forKey: "pinly.softPaywallShown"))
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

        vm.handleArrival(place: place, stopIndex: 0, context: context, placeStore: repository)

        XCTAssertTrue(place.isVisited)
        XCTAssertEqual(place.visitCount, 1)
        XCTAssertEqual(vm.arrivedPlaceName, "Museum")
        XCTAssertEqual(vm.pendingRatingPlace?.id, place.id)
        XCTAssertEqual(vm.pendingRatingStopIndex, 0)
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

    // MARK: - Anı Fotoğrafları (FAZ 3)

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        return renderer.image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }

    func test_addMemoryPhoto_storesFileNameUnderStopIndex() {
        let memories = MockRouteMemoryStoring()
        let analytics = MockAnalyticsTracking()
        let vm = makeViewModel(analytics: analytics, routeMemories: memories)
        let place = Place(name: "Cafe")
        let context = makeInMemoryContext()
        let repository = MockPlaceRepository()

        let added = vm.addMemoryPhoto(makeTestImage(), stopIndex: 1, alsoSaveAsPlacePhoto: false, place: place, context: context, placeStore: repository)

        XCTAssertTrue(added)
        XCTAssertEqual(vm.stopPhotos[1]?.count, 1)
        XCTAssertEqual(memories.saveCallCount, 1)
        XCTAssertTrue(analytics.trackedEvents.contains(.memoryPhotoAdded))
        XCTAssertNil(place.photoFileName, "alsoSaveAsPlacePhoto kapalıyken mekan fotoğrafı DEĞİŞMEMELİ")
    }

    func test_addMemoryPhoto_maxThreePerStop_fourthRejected() {
        let vm = makeViewModel()
        let place = Place(name: "Cafe")
        let context = makeInMemoryContext()
        let repository = MockPlaceRepository()

        for _ in 0..<3 {
            XCTAssertTrue(vm.addMemoryPhoto(makeTestImage(), stopIndex: 0, alsoSaveAsPlacePhoto: false, place: place, context: context, placeStore: repository))
        }
        let fourth = vm.addMemoryPhoto(makeTestImage(), stopIndex: 0, alsoSaveAsPlacePhoto: false, place: place, context: context, placeStore: repository)

        XCTAssertFalse(fourth)
        XCTAssertEqual(vm.stopPhotos[0]?.count, 3)
    }

    func test_addMemoryPhoto_alsoSaveAsPlacePhoto_writesToPlacePhotoStoreToo() {
        let placePhotos = MockPlacePhotoStoring()
        let vm = makeViewModel(placePhotos: placePhotos)
        let place = Place(name: "Cafe")
        let context = makeInMemoryContext()
        let repository = MockPlaceRepository()

        vm.addMemoryPhoto(makeTestImage(), stopIndex: 0, alsoSaveAsPlacePhoto: true, place: place, context: context, placeStore: repository)

        XCTAssertEqual(placePhotos.saveCallCount, 1)
        XCTAssertNotNil(place.photoFileName)
    }

    func test_memoryPhotos_mapsStopIndexToPlaceName_sortedByStopIndex() {
        let memories = MockRouteMemoryStoring()
        let vm = makeViewModel(routeMemories: memories)
        let placeA = Place(name: "Moda")
        let placeB = Place(name: "Bahariye")
        let context = makeInMemoryContext()
        let repository = MockPlaceRepository()

        vm.addMemoryPhoto(makeTestImage(), stopIndex: 1, alsoSaveAsPlacePhoto: false, place: placeB, context: context, placeStore: repository)
        vm.addMemoryPhoto(makeTestImage(), stopIndex: 0, alsoSaveAsPlacePhoto: false, place: placeA, context: context, placeStore: repository)

        let photos = vm.memoryPhotos(routePlaces: [placeA, placeB])

        XCTAssertEqual(photos.map(\.stopIndex), [0, 1])
        XCTAssertEqual(photos.map(\.stopName), ["Moda", "Bahariye"])
    }

    func test_shareMemoryImage_fromLiveRoute_tracksAnalyticsAndBadges() {
        let analytics = MockAnalyticsTracking()
        let composer = MockMemoryCardComposing()
        let badges = MockBadgeServicing()
        badges.badgesToUnlockOnCheck = [.paylasimci]
        let vm = makeViewModel(badges: badges, analytics: analytics, memoryCards: composer)
        let repository = MockPlaceRepository()

        let image = vm.shareMemoryImage(
            format: .story,
            routePlaces: [Place(name: "Moda")],
            fallbackRouteName: "Rota",
            totalDistance: 1000,
            totalTime: 600,
            mapSnapshot: nil,
            placeStore: repository
        )

        XCTAssertEqual(composer.composeStoryCallCount, 1)
        XCTAssertTrue(analytics.trackedEvents.contains(.memoryCardShared(format: "story")))
        XCTAssertEqual(repository.pendingBadges, [.paylasimci])
        XCTAssertNotNil(image)
    }

    func test_shareMemoryImage_fromHistory_usesStoredPhotos_noMapSnapshot() {
        let memories = MockRouteMemoryStoring()
        let composer = MockMemoryCardComposing()
        let vm = makeViewModel(routeMemories: memories, memoryCards: composer)
        let historyID = UUID()
        let history = RouteHistory(id: historyID, routeName: "Eski Rota", placeNames: ["Moda"], totalDistanceMeters: 500, durationSeconds: 300, stepCount: 400)
        let fileName = try! memories.save(makeTestImage(), historyID: historyID, stopIndex: 0)
        history.setMemoryPhotos([RouteMemoryPhoto(stopIndex: 0, stopName: "Moda", fileName: fileName)])

        _ = vm.shareMemoryImage(format: .post, history: history)

        XCTAssertEqual(composer.composePostCallCount, 1)
        XCTAssertEqual(composer.lastPhotos.count, 1)
        XCTAssertNil(composer.lastMapSnapshot, "Günlük'ten yeniden paylaşımda koordinat yok — harita nil olmalı")
    }
}
