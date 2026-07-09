import Foundation
@testable import Pinly

final class MockBadgeServicing: BadgeServicing {
    var unlockedBadges: Set<Badge> = []
    var consecutiveDays = 0
    var completedRouteCount = 0
    var sharedRouteCount = 0
    var savedRouteCount = 0

    var badgesToUnlockOnCheck: [Badge] = []
    var checkCallCount = 0

    @MainActor
    func check(placeStore: PlaceRepository) -> [Badge] {
        checkCallCount += 1
        let newOnes = badgesToUnlockOnCheck.filter { !unlockedBadges.contains($0) }
        unlockedBadges.formUnion(newOnes)
        return newOnes
    }

    func recordRouteStarted() { }
    func recordRouteCompleted() { completedRouteCount += 1 }
    func recordRouteShared() { sharedRouteCount += 1 }
    func recordSavedRoute() { savedRouteCount += 1 }
    func recordAppOpen() { }

    @MainActor
    func progressText(for badge: Badge, placeStore: PlaceRepository) -> String {
        "mock-progress"
    }
}
