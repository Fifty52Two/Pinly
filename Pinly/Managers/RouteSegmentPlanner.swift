import Foundation
import CoreLocation

// MARK: - RouteSegmentPlanner

/// `RouteManager.calculateRoutes`'un rota PLANLAMA katmanı — saf fonksiyon, ağ çağrısı yapmaz.
/// Dönen dizi `routePlaces` ile HER ZAMAN aynı uzunlukta ve indeks hizalıdır: plan[i], routePlaces[i]
/// durağına giden bacağı temsil eder. `nil` eleman iki durumdan biri demektir:
///   1. Durağın kendi koordinatı yok (hedef bilinmiyor — MKDirections'a hiç gönderilmez), veya
///   2. Önceki geçerli konum bilinmiyor (userLocation nil VE bu, koordinatlı ilk durak).
/// Koordinatsız bir durak listenin ortasında olduğunda `cursor` güncellenmez — bir SONRAKİ
/// koordinatlı durak, ondan ÖNCEKİ koordinatlı duraktan (veya kullanıcı konumundan) bacak kurar;
/// böylece segment[i] ↔ routePlaces[i] hizası hiçbir durumda kaymaz.
enum RouteSegmentPlanner {
    struct Leg {
        let from: CLLocationCoordinate2D
        let to: CLLocationCoordinate2D
    }

    static func plan(places: [Place], userLocation: CLLocationCoordinate2D?) -> [Leg?] {
        var cursor = userLocation
        var result: [Leg?] = []
        result.reserveCapacity(places.count)
        for place in places {
            if let dest = place.coordinate {
                result.append(cursor.map { Leg(from: $0, to: dest) })
                cursor = dest
            } else {
                result.append(nil)
            }
        }
        return result
    }
}
