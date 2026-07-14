import Foundation
import CoreLocation

// MARK: - RouteOrderOptimizer

/// Durak sırasını yürüme mesafesine göre iyileştiren saf yardımcı.
/// Basit nearest-neighbor — mükemmel TSP değil, ama kötü elle sıralamayı
/// belirgin biçimde kısaltır. State/framework bağımlılığı yok, test edilebilir.
enum RouteOrderOptimizer {
    /// `start` verilirse tüm duraklar oradan başlayarak sıralanır.
    /// `start` yoksa ilk durak sabit kalır, kalanlar ona göre dizilir.
    /// Koordinatsız mekanlar sıranın sonuna orijinal sıralarıyla eklenir.
    static func nearestNeighborOrder(places: [Place], start: CLLocationCoordinate2D?) -> [Place] {
        let located = places.filter { $0.coordinate != nil }
        let unlocated = places.filter { $0.coordinate == nil }
        guard located.count >= 2 else { return places }

        var remaining = located
        var ordered: [Place] = []
        var cursor: CLLocationCoordinate2D
        if let start {
            cursor = start
        } else {
            let first = remaining.removeFirst()
            ordered.append(first)
            cursor = first.coordinate!
        }

        while !remaining.isEmpty {
            let nearestIndex = remaining.indices.min(by: { a, b in
                distance(from: cursor, to: remaining[a].coordinate!)
                    < distance(from: cursor, to: remaining[b].coordinate!)
            })!
            let next = remaining.remove(at: nearestIndex)
            ordered.append(next)
            cursor = next.coordinate!
        }
        return ordered + unlocated
    }

    private static func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
