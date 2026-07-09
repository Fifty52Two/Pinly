import Foundation
@testable import Pinly

final class MockRouteExporting: RouteExporting {
    var pdfURLResult: URL?
    var gpxURLResult: URL?

    func buildPDFFile(for places: [Place], name: String, totalDistance: String, totalTime: String) -> URL? {
        pdfURLResult
    }

    func buildGPXFile(for places: [Place], name: String) -> URL? {
        gpxURLResult
    }
}
