import ActivityKit
import Foundation

// Bu dosya hem ana app hem de Widget Extension tarafından kullanılır.
// Widget Extension target'ına da eklenmelidir.

struct PinlyActivityAttributes: ActivityAttributes {
    // Navigasyon boyunca sabit kalan bilgiler
    public struct ContentState: Codable, Hashable {
        var instruction: String
        var remainingDistance: String
        var stopIndex: Int      // 1-based (mevcut durak numarası)
        var totalStops: Int
        var nextPlaceName: String
        var completionPercentage: Double
    }

    // Navigasyon başladığında set edilen, değişmeyen bilgiler
    var routeName: String
}
