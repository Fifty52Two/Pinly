import XCTest
@testable import Pinly

final class PlaceImporterTests: XCTestCase {

    // MARK: - Single Place URL round-trip

    func test_singlePlaceURL_roundTrip_preservesAllFields() {
        let coder = DefaultRouteURLCoder()
        let place = Place(name: "Ada Kahve", category: PlaceCategory.cafe.rawValue, address: "Kadıköy", notes: "Kahvesi güzel")
        place.latitude = 40.99
        place.longitude = 29.02

        let url = coder.buildURL(for: place)
        XCTAssertNotNil(url)

        let parsed = coder.parse(url: url!)
        XCTAssertEqual(parsed?.name, "Ada Kahve")
        XCTAssertEqual(parsed?.category, PlaceCategory.cafe.rawValue)
        XCTAssertEqual(parsed?.address, "Kadıköy")
        XCTAssertEqual(parsed?.notes, "Kahvesi güzel")
        XCTAssertEqual(parsed?.latitude, 40.99)
        XCTAssertEqual(parsed?.longitude, 29.02)
    }

    func test_singlePlaceURL_legacyScheme_stillParses() {
        let coder = DefaultRouteURLCoder()
        let url = URL(string: "notiongo://addplace?name=Eski%20Mekan&category=Park&address=&notes=")!
        let parsed = coder.parse(url: url)
        XCTAssertEqual(parsed?.name, "Eski Mekan")
    }

    func test_singlePlaceURL_missingName_returnsNil() {
        let coder = DefaultRouteURLCoder()
        let url = URL(string: "pinly://addplace?category=Park")!
        XCTAssertNil(coder.parse(url: url))
    }

    // MARK: - Route URL round-trip (new format)

    func test_routeURL_newFormat_roundTrip_preservesPlacesNameAndCategory() {
        let coder = DefaultRouteURLCoder()
        let a = Place(name: "Durak A", category: PlaceCategory.museum.rawValue, address: "Adres A", notes: "")
        a.latitude = 41.0; a.longitude = 29.0
        let b = Place(name: "Durak B", category: PlaceCategory.park.rawValue, address: "Adres B", notes: "Not B")

        let url = coder.buildRouteURL(for: [a, b], name: "Pazar Rotası", category: .city)
        XCTAssertNotNil(url)

        let imported = coder.parseRouteFull(url: url!)
        XCTAssertEqual(imported?.name, "Pazar Rotası")
        XCTAssertEqual(imported?.category, .city)
        XCTAssertEqual(imported?.places.map(\.name), ["Durak A", "Durak B"])
        XCTAssertEqual(imported?.places.first?.latitude, 41.0)
        XCTAssertEqual(imported?.places.last?.notes, "Not B")
    }

    func test_routeURL_legacyPlainArrayFormat_stillParses() {
        let coder = DefaultRouteURLCoder()
        let rawArray: [[String: String]] = [
            ["name": "Eski Durak", "category": PlaceCategory.general.rawValue, "address": "", "notes": ""]
        ]
        let json = try! JSONSerialization.data(withJSONObject: rawArray)
        let b64 = json.base64EncodedString()
        let url = URL(string: "pinly://route?data=\(b64)")!

        let imported = coder.parseRouteFull(url: url)
        XCTAssertEqual(imported?.places.map(\.name), ["Eski Durak"])
        XCTAssertNil(imported?.name)
        XCTAssertNil(imported?.category)
    }

    func test_routeURL_corruptBase64_returnsNil() {
        let coder = DefaultRouteURLCoder()
        let url = URL(string: "pinly://route?data=%F0%9F%98%80notvalidbase64!!!")!
        XCTAssertNil(coder.parseRouteFull(url: url))
    }

    func test_routeURL_emptyPlacesArray_returnsNil() {
        let coder = DefaultRouteURLCoder()
        let json = try! JSONSerialization.data(withJSONObject: ["places": [[String: String]]()])
        let b64 = json.base64EncodedString()
        let url = URL(string: "pinly://route?data=\(b64)")!
        XCTAssertNil(coder.parseRouteFull(url: url))
    }

    // MARK: - Export filename sanitization (bug B9 regression)

    func test_buildGPXFile_sanitizesSlashesInRouteName() {
        let exporter = DefaultRouteExporter()
        let place = Place(name: "Tek Durak")
        place.latitude = 41.0; place.longitude = 29.0

        let url = exporter.buildGPXFile(for: [place], name: "İstanbul/Kadıköy Rotası")
        XCTAssertNotNil(url)
        XCTAssertFalse(url!.lastPathComponent.contains("/"))
        XCTAssertTrue(url!.lastPathComponent.hasSuffix(".gpx"))
    }

    func test_buildPDFFile_sanitizesColonInRouteName() {
        let exporter = DefaultRouteExporter()
        let place = Place(name: "Tek Durak", address: "Bir adres")

        let url = exporter.buildPDFFile(for: [place], name: "Rota: Akşam Turu", totalDistance: "1 km", totalTime: "10 dk")
        XCTAssertNotNil(url)
        XCTAssertFalse(url!.lastPathComponent.contains(":"))
        XCTAssertTrue(url!.lastPathComponent.hasSuffix(".pdf"))
    }

    func test_buildGPXFile_emptyRouteName_fallsBackToDefaultFileName() {
        let exporter = DefaultRouteExporter()
        let place = Place(name: "Tek Durak")
        place.latitude = 41.0; place.longitude = 29.0

        let url = exporter.buildGPXFile(for: [place], name: "")
        XCTAssertEqual(url?.lastPathComponent, "rota.gpx")
    }

    func test_buildGPXFile_onlyInvalidCharacters_joinsWithDashesRatherThanEmpty() {
        let exporter = DefaultRouteExporter()
        let place = Place(name: "Tek Durak")
        place.latitude = 41.0; place.longitude = 29.0

        // sanitizedFileName splits on invalid chars and joins with "-", so "///"
        // becomes "---", not an empty string — the "rota" fallback only triggers
        // for a genuinely empty name.
        let url = exporter.buildGPXFile(for: [place], name: "///")
        XCTAssertEqual(url?.lastPathComponent, "---.gpx")
    }
}
