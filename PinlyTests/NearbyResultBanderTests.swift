import XCTest
import CoreLocation
@testable import Pinly

/// Yakınımda yarıçap bug'ının regresyon testleri: "3/5 km çalışmıyor, hep ~1 km" —
/// kök neden B, en-yakın-25 kırpımının yoğun bölgede yarıçapı anlamsız kılması.
final class NearbyResultBanderTests: XCTestCase {

    private func place(_ distance: Double) -> NearbyPlace {
        NearbyPlace(
            name: "P\(Int(distance))",
            address: "",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            category: .general,
            distanceMeters: distance
        )
    }

    func test_radiusUpToOneKm_behavesAsNearestFirst() {
        let places = (0..<30).map { place(Double($0) * 30) }   // 0..870m

        let result = NearbyResultBander.diversify(places, radius: 1000)

        XCTAssertEqual(result.count, 25)
        XCTAssertEqual(result.map(\.distanceMeters), result.map(\.distanceMeters).sorted())
        XCTAssertEqual(result.first?.distanceMeters, 0)
    }

    /// Asıl bug: yoğun bölgede (900 mekan hepsi <1km) yarıçap 3 km yapılsa bile eski
    /// "en yakın 25" mantığı SADECE bu yoğun kümeden seçerdi — 1-3 km bandındaki mekanlar
    /// radius filtresini geçmiş olsa bile listeye HİÇ giremezdi. Bantlama bunu düzeltir.
    func test_radiusAboveOneKm_denseNearCluster_stillSurfacesFartherResults() {
        let denseNear = (0..<900).map { place(Double($0)) }              // 0-899m, çok yoğun
        let farBand1 = [place(1500), place(1600)]                        // 1-2 km bandı
        let farBand2 = [place(2500), place(2600)]                        // 2-3 km bandı
        let all = denseNear + farBand1 + farBand2

        let result = NearbyResultBander.diversify(all, radius: 3000)

        XCTAssertEqual(result.count, 25)
        XCTAssertTrue(
            result.contains { $0.distanceMeters >= 1000 },
            "eski 'en yakın 25' davranışı bu uzak sonuçları hiç göstermezdi"
        )
    }

    func test_radiusAboveOneKm_resultsSpreadAcrossThreeBands() {
        // Her bantta yeterince mekan olan senaryo: 3 km yarıçapta bant sınırları 1000/2000/3000
        let band0 = (0..<10).map { place(Double($0) * 50) }        // 0-450m
        let band1 = (0..<10).map { place(1000 + Double($0) * 50) } // 1000-1450m
        let band2 = (0..<10).map { place(2000 + Double($0) * 50) } // 2000-2450m
        let all = band0 + band1 + band2

        let result = NearbyResultBander.diversify(all, radius: 3000)

        let hasBand0 = result.contains { $0.distanceMeters < 1000 }
        let hasBand1 = result.contains { $0.distanceMeters >= 1000 && $0.distanceMeters < 2000 }
        let hasBand2 = result.contains { $0.distanceMeters >= 2000 }
        XCTAssertTrue(hasBand0 && hasBand1 && hasBand2, "üç bandın hepsinden sonuç gelmeli")
    }

    func test_emptyBand_backfillsFromOtherBands() {
        // Orta bant (1000-2000m) tamamen boş — round-robin diğer bantlardan doldurmalı
        let band0 = (0..<15).map { place(Double($0) * 50) }         // 0-700m
        let band2 = (0..<15).map { place(2000 + Double($0) * 50) }  // 2000-2700m
        let all = band0 + band2

        let result = NearbyResultBander.diversify(all, radius: 3000)

        XCTAssertEqual(result.count, 25)
    }

    func test_fewerThan25TotalResults_returnsAllWithoutCrashing() {
        let places = (0..<5).map { place(Double($0) * 500) }

        let result = NearbyResultBander.diversify(places, radius: 3000)

        XCTAssertEqual(result.count, 5)
    }

    func test_resultsAlwaysSortedWithinTheirOwnBand() {
        let shuffled = [place(400), place(100), place(300), place(200)]

        let result = NearbyResultBander.diversify(shuffled, radius: 3000)

        // Tek bant (hepsi <1000m) içinde mesafe sıralı olmalı
        XCTAssertEqual(result.map(\.distanceMeters), [100, 200, 300, 400])
    }
}
