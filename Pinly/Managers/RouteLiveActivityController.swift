import Foundation
import ActivityKit

// MARK: - LiveActivitySnapshot

/// RouteManager'ın anlık navigasyon durumundan türetilen, Live Activity
/// güncellemesi için gereken minimal veri anlık görüntüsü. Controller `Place`
/// tipini hiç bilmez — RouteManager gerekli alanları (başlık, sıradaki durak adı,
/// toplam durak sayısı) burada çözüp geçirir.
struct LiveActivitySnapshot {
    let title: String
    let instruction: String
    let remainingDistance: String
    let stopIndex: Int
    let totalStops: Int
    let nextPlaceName: String
    let completionPercentage: Double
}

// MARK: - RouteLiveActivityPresenting

/// Kilit ekranı Live Activity (ActivityKit) yönetiminin protokolü.
@MainActor
protocol RouteLiveActivityPresenting: AnyObject {
    func start(snapshot: LiveActivitySnapshot)
    func update(snapshot: LiveActivitySnapshot)
    func end()
}

// MARK: - RouteLiveActivityController

/// `RouteLiveActivityPresenting`'in somut implementasyonu — Live Activity
/// yaşam döngüsü RouteManager'ın rota hesaplama/navigasyon mantığından
/// ayrılmış, tek başına okunabilir/test edilebilir.
@MainActor
final class RouteLiveActivityController: RouteLiveActivityPresenting {
    private var liveActivity: Activity<PinlyActivityAttributes>?

    func start(snapshot: LiveActivitySnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard snapshot.totalStops > 0 else { return }

        let state = PinlyActivityAttributes.ContentState(
            instruction: snapshot.instruction.isEmpty ? "Navigasyon başlıyor..." : snapshot.instruction,
            remainingDistance: snapshot.remainingDistance,
            stopIndex: snapshot.stopIndex,
            totalStops: snapshot.totalStops,
            nextPlaceName: snapshot.nextPlaceName,
            completionPercentage: snapshot.completionPercentage
        )
        let attributes = PinlyActivityAttributes(routeName: snapshot.title)

        liveActivity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(snapshot: LiveActivitySnapshot) {
        guard let activity = liveActivity else { return }
        let state = PinlyActivityAttributes.ContentState(
            instruction: snapshot.instruction,
            remainingDistance: snapshot.remainingDistance,
            stopIndex: snapshot.stopIndex,
            totalStops: snapshot.totalStops,
            nextPlaceName: snapshot.nextPlaceName,
            completionPercentage: snapshot.completionPercentage
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity = liveActivity else { return }
        Task { await activity.end(.init(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate) }
        liveActivity = nil
    }
}
