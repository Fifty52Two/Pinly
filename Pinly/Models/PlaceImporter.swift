import Foundation
import CoreLocation
import SwiftData
import UIKit

// MARK: - Route Category

enum RouteCategory: String, CaseIterable, Codable {
    case city         = "Şehir İçi"
    case dayTrip      = "Şehir Dışı"
    case international = "Yurt Dışı"

    var icon: String {
        switch self {
        case .city:          return "building.2.fill"
        case .dayTrip:       return "car.fill"
        case .international: return "airplane"
        }
    }
}

// MARK: - Import Data

struct RouteImport {
    let places: [PlaceImportData]
    let name: String?
    let category: RouteCategory?
}

struct PlaceImportData {
    let name: String
    let category: String
    let address: String
    let notes: String
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Girdi Doğrulama Sınırları

/// Derin link / QR / dosya içe aktarımı GÜVENSİZ dış girdidir (MASVS-CODE-4).
/// Bu sınırlar bellek DoS'unu ve bozuk verinin (NaN koordinat vb.) SwiftData +
/// MapKit'e sızmasını engeller.
enum ImportLimits {
    /// Tek rota linkinde kabul edilen en fazla mekan — aşarsa link REDDEDİLİR
    /// (sessiz kırpma rotayı yalancı yapar).
    static let maxPlacesPerRoute = 50
    /// base64 rota payload'ının üst boyutu (QR kapasitesinin çok üstü; elle
    /// üretilmiş dev deep link'lere karşı).
    static let maxPayloadBytes = 64 * 1024
    /// Swarm içe aktarımında işlenecek en fazla check-in — kullanıcının kendi
    /// dosyası olduğundan kırpma kabul edilebilir (bellek koruması).
    static let maxSwarmItems = 500
}

/// Koordinat çifti ancak ikisi de sonlu ve dünya sınırları içindeyse geçerli.
/// Geçersizse (nil, nil) döner — mekan koordinatsız (adresli) içe aktarılır,
/// mevcut optional-koordinat tasarımıyla uyumlu.
func validatedCoordinate(lat: Double?, lon: Double?) -> (lat: Double?, lon: Double?) {
    guard let lat, let lon,
          lat.isFinite, lon.isFinite,
          (-90.0...90.0).contains(lat),
          (-180.0...180.0).contains(lon)
    else { return (nil, nil) }
    return (lat, lon)
}

// MARK: - RouteURLCoding

/// Tek mekan / rota derin link URL'lerinin build + parse edilmesi.
protocol RouteURLCoding {
    func buildURL(for place: Place) -> URL?
    func parse(url: URL) -> PlaceImportData?
    func buildRouteURL(for places: [Place], name: String?, category: RouteCategory?) -> URL?
    func parseRouteFull(url: URL) -> RouteImport?
}

struct DefaultRouteURLCoder: RouteURLCoding {

    private let primaryScheme = "pinly"
    private let legacyScheme = "notiongo"

    func buildURL(for place: Place) -> URL? {
        var components = URLComponents()
        components.scheme = primaryScheme
        components.host = "addplace"

        var items: [URLQueryItem] = [
            URLQueryItem(name: "name", value: place.name),
            URLQueryItem(name: "category", value: place.placeCategory.rawValue),
            URLQueryItem(name: "address", value: place.address),
            URLQueryItem(name: "notes", value: place.notes),
        ]

        if let lat = place.latitude, let lon = place.longitude {
            items.append(URLQueryItem(name: "lat", value: String(lat)))
            items.append(URLQueryItem(name: "lon", value: String(lon)))
        }

        components.queryItems = items
        return components.url
    }

    func parse(url: URL) -> PlaceImportData? {
        guard let scheme = url.scheme,
              [primaryScheme, legacyScheme].contains(scheme),
              url.host == "addplace"
        else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems ?? []

        func value(_ key: String) -> String { query.first(where: { $0.name == key })?.value ?? "" }

        let name = value("name")
        guard !name.isEmpty else { return nil }

        let rawLat = query.first(where: { $0.name == "lat" }).flatMap { Double($0.value ?? "") }
        let rawLon = query.first(where: { $0.name == "lon" }).flatMap { Double($0.value ?? "") }
        let coord = validatedCoordinate(lat: rawLat, lon: rawLon)

        return PlaceImportData(
            name: name,
            category: value("category").isEmpty ? PlaceCategory.general.rawValue : value("category"),
            address: value("address"),
            notes: value("notes"),
            latitude: coord.lat,
            longitude: coord.lon
        )
    }

    // Route URL (pinly://route?data=<base64JSON>)
    // JSON format: {"places": [...], "name": "...", "category": "..."}
    // Backwards compat: plain array also accepted by parseRouteFull

    func buildRouteURL(for places: [Place], name: String? = nil, category: RouteCategory? = nil) -> URL? {
        let placeItems: [[String: String]] = places.map { p in
            var d: [String: String] = [
                "name": p.name,
                "category": p.placeCategory.rawValue,
                "address": p.address,
                "notes": p.notes,
            ]
            if let lat = p.latitude  { d["lat"] = String(lat) }
            if let lon = p.longitude { d["lon"] = String(lon) }
            return d
        }
        var wrapper: [String: Any] = ["places": placeItems]
        if let name = name, !name.isEmpty { wrapper["name"] = name }
        if let category = category { wrapper["category"] = category.rawValue }

        guard let json   = try? JSONSerialization.data(withJSONObject: wrapper),
              let b64str = String(data: json.base64EncodedData(), encoding: .utf8)
        else { return nil }
        var c = URLComponents()
        c.scheme = primaryScheme
        c.host   = "route"
        c.queryItems = [URLQueryItem(name: "data", value: b64str)]
        return c.url
    }

    func parseRouteFull(url: URL) -> RouteImport? {
        guard let scheme = url.scheme,
              [primaryScheme, legacyScheme].contains(scheme),
              url.host == "route"
        else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let b64  = comps?.queryItems?.first(where: { $0.name == "data" })?.value,
              b64.utf8.count <= ImportLimits.maxPayloadBytes,
              let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data)
        else { return nil }

        // New format: {"places": [...], "name": "...", "category": "..."}
        let rawPlaces: [[String: String]]
        let routeName: String?
        let routeCategory: RouteCategory?
        if let wrapper = json as? [String: Any],
           let arr = wrapper["places"] as? [[String: String]] {
            rawPlaces = arr
            routeName = wrapper["name"] as? String
            routeCategory = (wrapper["category"] as? String).flatMap { RouteCategory(rawValue: $0) }
        } else if let arr = json as? [[String: String]] {
            // Legacy format: plain array
            rawPlaces = arr
            routeName = nil
            routeCategory = nil
        } else {
            return nil
        }

        let places = rawPlaces.compactMap { d -> PlaceImportData? in
            guard let name = d["name"], !name.isEmpty else { return nil }
            let coord = validatedCoordinate(
                lat: d["lat"].flatMap(Double.init),
                lon: d["lon"].flatMap(Double.init)
            )
            return PlaceImportData(
                name: name,
                category: d["category"] ?? PlaceCategory.general.rawValue,
                address: d["address"] ?? "",
                notes: d["notes"] ?? "",
                latitude:  coord.lat,
                longitude: coord.lon
            )
        }
        // Aşırı kalabalık rota REDDEDİLİR (kırpılmaz) — kırpılmış rota kullanıcıya
        // eksiksizmiş gibi görünür, yanıltıcıdır.
        guard !places.isEmpty, places.count <= ImportLimits.maxPlacesPerRoute else { return nil }
        return RouteImport(places: places, name: routeName, category: routeCategory)
    }
}

// MARK: - SwarmImporting

/// Foursquare/Swarm `checkins.json` dışa aktarımının parse edilmesi.
protocol SwarmImporting {
    func parseSwarm(data: Data) -> [PlaceImportData]?
}

struct DefaultSwarmImporter: SwarmImporting {

    func parseSwarm(data: Data) -> [PlaceImportData]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let checkinsObj = json["checkins"] as? [String: Any],
              let items = checkinsObj["items"] as? [[String: Any]]
        else { return nil }

        var seen = Set<String>()
        var result: [PlaceImportData] = []

        // Kullanıcının kendi dosyası — kırpma kabul edilebilir (bellek koruması)
        for item in items.prefix(ImportLimits.maxSwarmItems) {
            guard let venue = item["venue"] as? [String: Any],
                  let name = venue["name"] as? String, !name.isEmpty
            else { continue }

            let venueId = (venue["id"] as? String) ?? name
            guard !seen.contains(venueId) else { continue }
            seen.insert(venueId)

            let location = venue["location"] as? [String: Any] ?? [:]
            let coord = validatedCoordinate(
                lat: location["lat"] as? Double,
                lon: location["lng"] as? Double
            )
            let lat = coord.lat
            let lon = coord.lon
            let street = location["address"] as? String ?? ""
            let city   = location["city"] as? String ?? ""
            let address = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")
            let shout   = item["shout"] as? String ?? ""

            let categories = venue["categories"] as? [[String: Any]] ?? []
            let primary = categories.first(where: { $0["primary"] as? Bool == true }) ?? categories.first
            let fqName  = (primary?["name"] as? String ?? "").lowercased()

            result.append(PlaceImportData(
                name: name,
                category: swarmCategory(fqName),
                address: address,
                notes: shout,
                latitude: lat,
                longitude: lon
            ))
        }

        return result.isEmpty ? nil : result
    }

    private func swarmCategory(_ fq: String) -> String {
        switch true {
        case fq.contains("restaurant") || fq.contains("food") || fq.contains("burger") ||
             fq.contains("pizza") || fq.contains("sushi") || fq.contains("grill") ||
             fq.contains("kebab") || fq.contains("bistro") || fq.contains("diner"):
            return PlaceCategory.restaurant.rawValue
        case fq.contains("coffee") || fq.contains("café") || fq.contains("cafe") || fq.contains("tea"):
            return PlaceCategory.cafe.rawValue
        case fq.contains("park") || fq.contains("garden") || fq.contains("outdoors") ||
             fq.contains("nature") || fq.contains("beach") || fq.contains("forest"):
            return PlaceCategory.park.rawValue
        case fq.contains("museum") || fq.contains("gallery") || fq.contains("art") ||
             fq.contains("cultural"):
            return PlaceCategory.museum.rawValue
        case fq.contains("historic") || fq.contains("monument") || fq.contains("landmark") ||
             fq.contains("castle") || fq.contains("mosque") || fq.contains("church") ||
             fq.contains("temple") || fq.contains("ruins"):
            return PlaceCategory.historical.rawValue
        case fq.contains("library") || fq.contains("bookstore") || fq.contains("book"):
            return PlaceCategory.library.rawValue
        case fq.contains("dessert") || fq.contains("ice cream") || fq.contains("bakery") ||
             fq.contains("pastry") || fq.contains("cake") || fq.contains("chocolate") ||
             fq.contains("patisserie") || fq.contains("candy"):
            return PlaceCategory.dessert.rawValue
        default:
            return PlaceCategory.general.rawValue
        }
    }
}

// MARK: - RouteExporting

/// Rota dışa aktarımı (PDF/GPX dosya üretimi).
protocol RouteExporting {
    func buildPDFFile(for places: [Place], name: String, totalDistance: String, totalTime: String) -> URL?
    func buildGPXFile(for places: [Place], name: String) -> URL?
}

struct DefaultRouteExporter: RouteExporting {

    // MARK: PDF Export (PDFKit)

    func buildPDFFile(for places: [Place], name: String, totalDistance: String = "", totalTime: String = "") -> URL? {
        let pageWidth: CGFloat = 595   // A4 points
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)

        var y: CGFloat = margin
        var pageOpen = false

        func beginPageIfNeeded() {
            if !pageOpen {
                UIGraphicsBeginPDFPage()
                pageOpen = true
                y = margin
            }
        }

        func newPageIfNeeded(neededHeight: CGFloat) {
            if y + neededHeight > pageHeight - margin {
                pageOpen = false
                beginPageIfNeeded()
            }
        }

        beginPageIfNeeded()

        // ---- Header ----
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.label
        ]
        let routeName = name.isEmpty ? "Rota" : name
        routeName.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 28), withAttributes: titleAttrs)
        y += 32

        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let dateStr = "Oluşturulma: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))"
        dateStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 18), withAttributes: subAttrs)
        y += 22

        if !totalDistance.isEmpty || !totalTime.isEmpty {
            let statsStr = [totalDistance, totalTime].filter { !$0.isEmpty }.joined(separator: "   •   ")
            statsStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 18), withAttributes: subAttrs)
            y += 22
        }

        // Divider
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setStrokeColor(UIColor.separator.cgColor)
        ctx?.setLineWidth(0.5)
        ctx?.move(to: CGPoint(x: margin, y: y + 4))
        ctx?.addLine(to: CGPoint(x: pageWidth - margin, y: y + 4))
        ctx?.strokePath()
        y += 16

        // ---- Place list ----
        let numAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.systemBlue
        ]
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.label
        ]
        let addrAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ]

        for (i, place) in places.enumerated() {
            let rowHeight: CGFloat = 18 + (place.address.isEmpty ? 0 : 16) + (place.notes.isEmpty ? 0 : 16) + 10
            newPageIfNeeded(neededHeight: rowHeight)

            let numStr = "\(i + 1)."
            numStr.draw(in: CGRect(x: margin, y: y, width: 24, height: 18), withAttributes: numAttrs)
            place.name.draw(in: CGRect(x: margin + 28, y: y, width: contentWidth - 28, height: 18), withAttributes: nameAttrs)
            y += 18
            if !place.address.isEmpty {
                place.address.draw(in: CGRect(x: margin + 28, y: y, width: contentWidth - 28, height: 16), withAttributes: addrAttrs)
                y += 16
            }
            if !place.notes.isEmpty {
                place.notes.draw(in: CGRect(x: margin + 28, y: y, width: contentWidth - 28, height: 16), withAttributes: noteAttrs)
                y += 16
            }
            y += 10
        }

        // ---- Footer ----
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        let footerY = pageHeight - margin + 4
        "Pinly ile oluşturuldu".draw(
            in: CGRect(x: margin, y: footerY, width: contentWidth, height: 14),
            withAttributes: footerAttrs
        )

        UIGraphicsEndPDFContext()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedFileName(routeName)).pdf")
        pdfData.write(to: url, atomically: true)
        return url
    }

    // Rota adındaki "/" ve ":" gibi karakterler dosya yazımını sessizce bozar
    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "rota" : cleaned
    }

    func buildGPXFile(for places: [Place], name: String) -> URL? {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<gpx version=\"1.1\" creator=\"Pinly\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        xml += "  <metadata><name>\(escapeXML(name))</name></metadata>\n"
        for place in places {
            guard let lat = place.latitude, let lon = place.longitude else { continue }
            let desc = place.address.isEmpty ? place.category : "\(place.category) - \(place.address)"
            xml += "  <wpt lat=\"\(lat)\" lon=\"\(lon)\"><name>\(escapeXML(place.name))</name><desc>\(escapeXML(desc))</desc></wpt>\n"
        }
        xml += "  <rte><name>\(escapeXML(name))</name>\n"
        for place in places {
            guard let lat = place.latitude, let lon = place.longitude else { continue }
            xml += "    <rtept lat=\"\(lat)\" lon=\"\(lon)\"><name>\(escapeXML(place.name))</name></rtept>\n"
        }
        xml += "  </rte>\n</gpx>"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedFileName(name)).gpx")
        try? xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func escapeXML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
