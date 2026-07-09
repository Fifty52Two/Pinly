import Foundation
@testable import Pinly

final class MockAdPresenting: AdPresenting {
    var showInterstitialCallCount = 0

    func showInterstitialIfNeeded(then completion: @escaping () -> Void) {
        showInterstitialCallCount += 1
        completion()
    }
}
