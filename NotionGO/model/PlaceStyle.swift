import SwiftUI

enum PlaceStyle {
    static func color(for category: String) -> Color {
        switch category.lowercased() {
        case "restaurant":               return .red
        case "café", "cafe",
             "calismak icin":            return .brown
        case "park":                     return .green
        case "museum":                   return .purple
        case "historical site":          return .orange
        case "library":                  return .blue
        case "tatli":                    return .pink
        default:                         return .gray
        }
    }

    static func icon(for category: String) -> String {
        switch category.lowercased() {
        case "restaurant":               return "fork.knife"
        case "café", "cafe",
             "calismak icin":            return "cup.and.saucer.fill"
        case "park":                     return "tree.fill"
        case "museum":                   return "building.columns.fill"
        case "historical site":          return "archivebox.fill"
        case "library":                  return "books.vertical.fill"
        case "tatli":                    return "birthday.cake.fill"
        default:                         return "mappin"
        }
    }
}
