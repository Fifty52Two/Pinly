import Foundation
@testable import Pinly

final class MockAnalyticsTracking: AnalyticsTracking {
    var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }
}
