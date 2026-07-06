import Foundation

// MARK: - BadgeServicing

/// Rozet ilerlemesi ve kilit açma mantığının protokolü.
/// View'lar `@Environment(\.badges)` üzerinden erişir; PlaceStore'a
/// constructor injection ile verilir.
protocol BadgeServicing: AnyObject {
    var unlockedBadges: Set<Badge> { get }
    var consecutiveDays: Int { get }
    var completedRouteCount: Int { get }
    var sharedRouteCount: Int { get }
    var savedRouteCount: Int { get }

    /// Yeni açılan rozetleri döndürür ve unlocked set'e kaydeder.
    @MainActor @discardableResult
    func check(placeStore: PlaceStore) -> [Badge]

    func recordRouteStarted()
    func recordRouteCompleted()
    func recordRouteShared()
    func recordSavedRoute()
    func recordAppOpen()
}

// MARK: - DefaultBadgeService

/// UserDefaults tabanlı rozet servisi (eski static `BadgeManager` mantığı).
final class DefaultBadgeService: BadgeServicing {
    static let shared = DefaultBadgeService()

    private let badgesKey           = "pinly.badges"
    private let completedRoutesKey  = "pinly.completedRoutes"
    private let sharedRoutesKey     = "pinly.sharedRoutes"
    private let savedRoutesKey      = "pinly.savedRoutes"
    private let consecutiveDaysKey  = "pinly.consecutiveDays"
    private let lastOpenDateKey     = "pinly.lastOpenDate"
    private let earlyRouteKey       = "pinly.earlyRoute"
    private let lateRouteKey        = "pinly.lateRoute"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var unlockedBadges: Set<Badge> {
        get {
            let raw = defaults.stringArray(forKey: badgesKey) ?? []
            return Set(raw.compactMap { Badge(rawValue: $0) })
        }
        set {
            defaults.set(newValue.map { $0.rawValue }, forKey: badgesKey)
        }
    }

    var completedRouteCount: Int {
        get { defaults.integer(forKey: completedRoutesKey) }
        set { defaults.set(newValue, forKey: completedRoutesKey) }
    }

    var sharedRouteCount: Int {
        get { defaults.integer(forKey: sharedRoutesKey) }
        set { defaults.set(newValue, forKey: sharedRoutesKey) }
    }

    var savedRouteCount: Int {
        get { defaults.integer(forKey: savedRoutesKey) }
        set { defaults.set(newValue, forKey: savedRoutesKey) }
    }

    var consecutiveDays: Int {
        get { defaults.integer(forKey: consecutiveDaysKey) }
        set { defaults.set(newValue, forKey: consecutiveDaysKey) }
    }

    var didStartEarlyRoute: Bool {
        get { defaults.bool(forKey: earlyRouteKey) }
        set { defaults.set(newValue, forKey: earlyRouteKey) }
    }

    var didStartLateRoute: Bool {
        get { defaults.bool(forKey: lateRouteKey) }
        set { defaults.set(newValue, forKey: lateRouteKey) }
    }

    func recordRouteCompleted() {
        completedRouteCount += 1
    }

    func recordRouteShared() {
        sharedRouteCount += 1
    }

    func recordSavedRoute() {
        savedRouteCount += 1
    }

    func recordRouteStarted() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 7 && hour < 9 { didStartEarlyRoute = true }
        if hour >= 21            { didStartLateRoute = true }
    }

    func recordAppOpen() {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = defaults.object(forKey: lastOpenDateKey) as? Date {
            let lastDay = Calendar.current.startOfDay(for: last)
            if Calendar.current.isDate(today, equalTo: lastDay, toGranularity: .day) {
                // Aynı gün, sayma
            } else if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today),
                      Calendar.current.isDate(lastDay, equalTo: yesterday, toGranularity: .day) {
                consecutiveDays += 1
            } else {
                consecutiveDays = 1
            }
        } else {
            consecutiveDays = 1
        }
        defaults.set(today, forKey: lastOpenDateKey)
    }

    /// Yeni açılan rozetleri döndürür ve unlocked set'e kaydeder.
    @MainActor @discardableResult
    func check(placeStore: PlaceStore) -> [Badge] {
        var current = unlockedBadges
        var newlyUnlocked: [Badge] = []

        func unlock(_ badge: Badge) {
            if !current.contains(badge) {
                current.insert(badge)
                newlyUnlocked.append(badge)
            }
        }

        let total      = placeStore.places.count
        let visited    = placeStore.places.filter { $0.isVisited }.count
        let categories = Set(placeStore.places.map { PlaceCategory.from($0.category) }).count
        let foodCount  = placeStore.places.filter {
            let cat = PlaceCategory.from($0.category)
            return cat == .restaurant || cat == .cafe
        }.count
        let parkCount  = placeStore.places.filter { PlaceCategory.from($0.category) == .park }.count
        let museumVisited = placeStore.places.filter {
            $0.isVisited && PlaceCategory.from($0.category) == .museum
        }.count

        // Mekan sayısı
        if total  >= 1   { unlock(.ilkAdim) }
        if total  >= 5   { unlock(.besli) }
        if total  >= 10  { unlock(.onlu) }
        if total  >= 20  { unlock(.yirmili) }
        if total  >= 50  { unlock(.ellili) }
        if total  >= 100 { unlock(.yuzlu) }

        // Ziyaret
        if visited >= 1  { unlock(.ilkZiyaret) }
        if visited >= 10 { unlock(.onZiyaret) }

        // Rota
        if completedRouteCount >= 1  { unlock(.gezgin) }
        if completedRouteCount >= 3  { unlock(.rotaci) }
        if completedRouteCount >= 10 { unlock(.rotaUstasi) }
        if savedRouteCount     >= 1  { unlock(.planlamaci) }

        // Keşif
        if categories  >= 5 { unlock(.kasif) }
        if parkCount   >= 5 { unlock(.parkSever) }
        if museumVisited >= 3 { unlock(.muzeSever) }
        if foodCount   >= 10 { unlock(.gurme) }

        // Zaman
        if didStartEarlyRoute { unlock(.sabahciKus) }
        if didStartLateRoute  { unlock(.geceKusu) }

        // Sosyal
        if sharedRouteCount >= 1 { unlock(.paylasimci) }
        if sharedRouteCount >= 5 { unlock(.sosyalKelebek) }

        // Sadakat
        if consecutiveDays >= 7 { unlock(.hafizalik) }

        if !newlyUnlocked.isEmpty {
            unlockedBadges = current
        }
        return newlyUnlocked
    }
}
