import Foundation
import UserNotifications

// MARK: - Haftalık İstatistikler

struct WeeklyStats {
    let routesCompleted: Int
    let totalSteps: Int
    let totalDistanceMeters: Double
    let topCategory: PlaceCategory?
    let topDistrict: String?
    let weekStart: Date
    let weekEnd: Date

    var formattedDistance: String {
        if totalDistanceMeters >= 1000 {
            return String(format: "%.1f km", totalDistanceMeters / 1000)
        } else {
            return String(format: "%.0f m", totalDistanceMeters)
        }
    }

    var isEmpty: Bool {
        routesCompleted == 0 && totalSteps == 0
    }
}

// MARK: - WeeklyReportManager

enum WeeklyReportManager {

    static func computeStats(places: [Place], histories: [RouteHistory]) -> WeeklyStats {
        let calendar  = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let weekEnd   = Date.now

        let recentHistories = histories.filter { $0.date >= weekStart }

        let steps    = recentHistories.reduce(0) { $0 + $1.stepCount }
        let distance = recentHistories.reduce(0) { $0 + $1.totalDistanceMeters }

        // En çok kayıtlı kategori (tüm mekanlar üzerinden)
        let catCounts = Dictionary(grouping: places.map { PlaceCategory.from($0.category) }, by: { $0 })
        let topCat    = catCounts.max(by: { $0.value.count < $1.value.count })?.key

        // En çok geçen ilçe (Place.district computed property)
        let districts   = places.compactMap { $0.district }.filter { !$0.isEmpty }
        let distCounts  = Dictionary(grouping: districts, by: { $0 })
        let topDistrict = distCounts.max(by: { $0.value.count < $1.value.count })?.key

        return WeeklyStats(
            routesCompleted: recentHistories.count,
            totalSteps: steps,
            totalDistanceMeters: distance,
            topCategory: topCat,
            topDistrict: topDistrict,
            weekStart: weekStart,
            weekEnd: weekEnd
        )
    }

    /// Pazar sabahı 09:00 tekrarlayan lokal bildirim planlar.
    static func scheduleWeeklyNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content      = UNMutableNotificationContent()
            content.title    = NSLocalizedString("Haftalık Özet", comment: "")
            content.body     = NSLocalizedString("Bu haftaki mekan maceralarına göz at!", comment: "")
            content.sound    = .default

            var comps        = DateComponents()
            comps.weekday    = 1   // Pazar
            comps.hour       = 9
            comps.minute     = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "pinly.weeklyReport",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}
