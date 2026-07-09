import Foundation
@testable import Pinly

final class MockHealthStatsProviding: HealthStatsProviding {
    var isAvailable = true
    var authorizationResult = true
    var statsResult: (steps: Int, distanceMeters: Double) = (0, 0)

    func requestAuthorization() async -> Bool {
        authorizationResult
    }

    func fetchRouteStats(from start: Date, to end: Date) async -> (steps: Int, distanceMeters: Double) {
        statsResult
    }
}
