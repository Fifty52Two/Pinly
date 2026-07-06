import Foundation
import SwiftData

// MARK: - RouteHistory Model

@Model
class RouteHistory {
    @Attribute(.unique) var id: UUID
    var routeName: String
    var date: Date
    var placeNames: [String]         // Place silinse de geçmiş kalır
    var totalDistanceMeters: Double
    var durationSeconds: Double
    var stepCount: Int
    var categoryRaw: String?         // RouteCategory rawValue

    var averageSpeedKmh: Double {
        guard durationSeconds > 0, totalDistanceMeters > 0 else { return 0 }
        return (totalDistanceMeters / 1000) / (durationSeconds / 3600)
    }

    var formattedDistance: String {
        if totalDistanceMeters >= 1000 {
            return String(format: "%.1f km", totalDistanceMeters / 1000)
        } else {
            return String(format: "%.0f m", totalDistanceMeters)
        }
    }

    var formattedDuration: String {
        let minutes = Int(durationSeconds / 60)
        if minutes < 60 { return "\(minutes) dk" }
        let hours = minutes / 60
        let mins  = minutes % 60
        return mins == 0 ? "\(hours) sa" : "\(hours) sa \(mins) dk"
    }

    init(routeName: String,
         date: Date = .now,
         placeNames: [String],
         totalDistanceMeters: Double,
         durationSeconds: Double,
         stepCount: Int,
         categoryRaw: String? = nil) {
        self.id                   = UUID()
        self.routeName            = routeName
        self.date                 = date
        self.placeNames           = placeNames
        self.totalDistanceMeters  = totalDistanceMeters
        self.durationSeconds      = durationSeconds
        self.stepCount            = stepCount
        self.categoryRaw          = categoryRaw
    }
}
