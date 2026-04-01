import Foundation
import CoreLocation
import SwiftData
import SwiftUI

// MARK: - PlaceCategory

enum PlaceCategory: String, CaseIterable, Codable {
    case restaurant = "Restaurant"
    case cafe       = "Café"
    case park       = "Park"
    case museum     = "Museum"
    case historical = "Historical Site"
    case library    = "Library"
    case dessert    = "Dessert"
    case general    = "General"

    var localizedName: String { NSLocalizedString(rawValue, comment: "") }

    var color: Color {
        switch self {
        case .restaurant: return .red
        case .cafe:       return .brown
        case .park:       return .green
        case .museum:     return .purple
        case .historical: return .orange
        case .library:    return .blue
        case .dessert:    return .pink
        case .general:    return .gray
        }
    }

    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .cafe:       return "cup.and.saucer.fill"
        case .park:       return "tree.fill"
        case .museum:     return "building.columns.fill"
        case .historical: return "archivebox.fill"
        case .library:    return "books.vertical.fill"
        case .dessert:    return "birthday.cake.fill"
        case .general:    return "mappin"
        }
    }

    // Mevcut veritabanındaki eski TR string'leri de tanı
    static func from(_ raw: String) -> PlaceCategory {
        switch raw.lowercased() {
        case "restaurant", "restoran":                  return .restaurant
        case "café", "cafe", "calismak icin", "çalışma": return .cafe
        case "park":                                    return .park
        case "museum", "müze":                          return .museum
        case "historical site", "tarihi":               return .historical
        case "library", "kütüphane":                    return .library
        case "tatli", "tatlı", "dessert":               return .dessert
        default:                                        return .general
        }
    }
}

// MARK: - Place

@Model
class Place {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var locationName: String
    var address: String
    var notes: String
    var isVisited: Bool = false
    var visitCount: Int = 0
    var userRating: Int? = nil
    var latitude: Double?
    var longitude: Double?

    init(name: String, category: String = PlaceCategory.general.rawValue, address: String = "", notes: String = "", isVisited: Bool = false) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.locationName = ""
        self.address = address
        self.notes = notes
        self.isVisited = isVisited
    }

    @Transient
    var placeCategory: PlaceCategory { PlaceCategory.from(category) }

    @Transient
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    @Transient
    var district: String {
        locationName
            .components(separatedBy: "/").first?
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? locationName
    }

    @Transient
    var categoryColor: Color { placeCategory.color }

    @Transient
    var categoryIcon: String { placeCategory.icon }
}
