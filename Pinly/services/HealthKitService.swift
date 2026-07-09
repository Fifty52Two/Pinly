import HealthKit

// MARK: - HealthStatsProviding

/// Gerçek adım sayısı / yürüme mesafesi sorgusu (HealthKit).
protocol HealthStatsProviding: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async -> Bool
    /// Verilen zaman aralığında gerçek adım sayısı ve yürüme mesafesini HealthKit'ten sorgular.
    func fetchRouteStats(from start: Date, to end: Date) async -> (steps: Int, distanceMeters: Double)
}

// MARK: - HealthKitService

final class HealthKitService: HealthStatsProviding {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let types: Set<HKQuantityType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning)
        ]
        return (try? await store.requestAuthorization(toShare: [], read: types)) != nil
    }

    func fetchRouteStats(from start: Date, to end: Date) async -> (steps: Int, distanceMeters: Double) {
        async let steps    = fetchSum(.stepCount, from: start, to: end)
        async let distance = fetchSum(.distanceWalkingRunning, from: start, to: end)
        let (s, d) = await (steps, distance)
        return (Int(s), d)
    }

    private func fetchSum(
        _ identifier: HKQuantityTypeIdentifier,
        from start: Date,
        to end: Date
    ) async -> Double {
        let type      = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let unit: HKUnit = identifier == .stepCount ? .count() : .meter()
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }
}
