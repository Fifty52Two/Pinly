import Foundation
@testable import Pinly

final class MockEntitlementProviding: EntitlementProviding {
    var isPro = false
    let freeLimit = 20

    func canAddPlace(currentCount: Int) -> Bool {
        isPro || currentCount < freeLimit
    }
}
