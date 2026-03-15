import Foundation
import CoreLocation
import SwiftData
import SwiftUI

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

    init(name: String, category: String = "Genel", address: String = "", notes: String = "", isVisited: Bool = false) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.locationName = ""
        self.address = address
        self.notes = notes
        self.isVisited = isVisited
    }

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
    var categoryColor: Color {
        switch category.lowercased() {
        case "restaurant", "restoran": return .red
        case "café", "cafe", "calismak icin", "çalışma": return .brown
        case "park": return .green
        case "museum", "müze": return .purple
        case "historical site", "tarihi": return .orange
        case "library", "kütüphane": return .blue
        case "tatli", "tatlı": return .pink
        default: return .gray
        }
    }

    @Transient
    var categoryIcon: String {
        switch category.lowercased() {
        case "restaurant", "restoran": return "fork.knife"
        case "café", "cafe", "calismak icin", "çalışma": return "cup.and.saucer.fill"
        case "park": return "tree.fill"
        case "museum", "müze": return "building.columns.fill"
        case "historical site", "tarihi": return "archivebox.fill"
        case "library", "kütüphane": return "books.vertical.fill"
        case "tatli", "tatlı": return "birthday.cake.fill"
        default: return "mappin"
        }
    }
}
