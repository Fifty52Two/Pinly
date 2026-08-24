import Foundation
@testable import Pinly

final class MockEntitlementProviding: EntitlementProviding {
    var isPro = false

    /// Production ile aynı davranış: mekan ekleme ücretsiz ve sınırsız.
    /// (Pro değer önerisi GPX/PDF export + reklamsız kullanım.)
    func canAddPlace(currentCount: Int) -> Bool {
        true
    }
}
