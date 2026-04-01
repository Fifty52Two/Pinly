import Foundation
import CoreLocation
import SwiftData

// MARK: - Import Data

struct PlaceImportData {
    let name: String
    let category: String
    let address: String
    let notes: String
    let latitude: Double?
    let longitude: Double?
}

// MARK: - PlaceImporter

enum PlaceImporter {

    private static let primaryScheme = "pinly"
    private static let legacyScheme = "notiongo"

    static func buildURL(for place: Place) -> URL? {
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

    static func parse(url: URL) -> PlaceImportData? {
        guard let scheme = url.scheme,
              [primaryScheme, legacyScheme].contains(scheme),
              url.host == "addplace"
        else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems ?? []

        func value(_ key: String) -> String { query.first(where: { $0.name == key })?.value ?? "" }

        let name = value("name")
        guard !name.isEmpty else { return nil }

        let lat = query.first(where: { $0.name == "lat" }).flatMap { Double($0.value ?? "") }
        let lon = query.first(where: { $0.name == "lon" }).flatMap { Double($0.value ?? "") }

        return PlaceImportData(
            name: name,
            category: value("category").isEmpty ? PlaceCategory.general.rawValue : value("category"),
            address: value("address"),
            notes: value("notes"),
            latitude: lat,
            longitude: lon
        )
    }

    // MARK: - Route URL (pinly://route?data=<base64JSON>)

    static func buildRouteURL(for places: [Place]) -> URL? {
        let items: [[String: String]] = places.map { p in
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
        guard let json   = try? JSONSerialization.data(withJSONObject: items),
              let b64str = String(data: json.base64EncodedData(), encoding: .utf8)
        else { return nil }
        var c = URLComponents()
          c.scheme = primaryScheme
        c.host   = "route"
        c.queryItems = [URLQueryItem(name: "data", value: b64str)]
        return c.url
    }

    static func parseRoute(url: URL) -> [PlaceImportData]? {
          guard let scheme = url.scheme,
              [primaryScheme, legacyScheme].contains(scheme),
              url.host == "route"
          else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let b64  = comps?.queryItems?.first(where: { $0.name == "data" })?.value,
              let data = Data(base64Encoded: b64),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else { return nil }
        let result = arr.compactMap { d -> PlaceImportData? in
            guard let name = d["name"], !name.isEmpty else { return nil }
            return PlaceImportData(
                name: name,
                category: d["category"] ?? PlaceCategory.general.rawValue,
                address: d["address"] ?? "",
                notes: d["notes"] ?? "",
                latitude:  d["lat"].flatMap(Double.init),
                longitude: d["lon"].flatMap(Double.init)
            )
        }
        return result.isEmpty ? nil : result
    }

    // Shared import logic used by both QRScannerView and deep-link handler.
    // If coordinates are present they're used directly; otherwise geocoding is performed.
    @MainActor
    static func save(_ data: PlaceImportData, placeStore: PlaceStore, context: ModelContext) async {
        if let lat = data.latitude, let lon = data.longitude {
            let place = Place(name: data.name, category: data.category, address: data.address, notes: data.notes)
            place.latitude = lat
            place.longitude = lon
            place.locationName = data.address
            context.insert(place)
            placeStore.save(context: context)
            placeStore.load(context: context)
        } else {
            await placeStore.addPlace(
                name: data.name,
                category: data.category,
                address: data.address,
                notes: data.notes,
                context: context
            )
        }
    }
}
