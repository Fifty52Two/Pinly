import SwiftUI
import MapKit
// MARK: - Navigation Map View

struct NavigationMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var routePolylines: [MKPolyline]
    let routePlaces: [Place]
    let userLocation: CLLocation?
    let nextWaypointCoordinate: CLLocationCoordinate2D?
    let currentWaypointIndex: Int
    let isNavigating: Bool
    let isPausedAtStop: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.mapType = .mutedStandard
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator

        // Camera: follow user during active navigation, manual region otherwise.
        // Region yalnızca binding'den yeni bir değer geldiğinde uygulanır —
        // aksi halde kullanıcı haritayı kaydıramaz (her update geri fırlatır).
        let shouldTrack = isNavigating && !isPausedAtStop
        if shouldTrack {
            if map.userTrackingMode != .follow {
                map.setUserTrackingMode(.follow, animated: true)
            }
            coordinator.lastAppliedRegion = nil
        } else {
            if map.userTrackingMode != .none {
                map.setUserTrackingMode(.none, animated: false)
            }
            let regionChanged = coordinator.lastAppliedRegion.map {
                abs($0.center.latitude - region.center.latitude) > 0.000001 ||
                abs($0.center.longitude - region.center.longitude) > 0.000001 ||
                abs($0.span.latitudeDelta - region.span.latitudeDelta) > 0.000001
            } ?? true
            if regionChanged {
                coordinator.lastAppliedRegion = region
                map.setRegion(region, animated: true)
            }
        }

        // Overlay'ler yalnızca polyline seti veya tamamlanan segment sayısı
        // değişince yeniden kurulur — her konum güncellemesinde silip eklemek
        // titremeye ve gereksiz CPU yüküne yol açıyordu.
        let completedCount = isPausedAtStop ? currentWaypointIndex + 1 : currentWaypointIndex
        let polylineIDs = routePolylines.map { ObjectIdentifier($0) }
        if coordinator.lastPolylineIDs != polylineIDs || coordinator.completedSegmentCount != completedCount {
            coordinator.completedSegmentCount = completedCount
            coordinator.lastPolylineIDs = polylineIDs
            map.removeOverlays(map.overlays)
            map.addOverlays(routePolylines.filter { $0.pointCount > 0 })
        }

        // Durak annotation'ları da yalnızca içerik değişince yeniden kurulur
        let annotationSignature = routePlaces.enumerated().map { index, place -> String in
            let skipped = isNavigating && !isPausedAtStop && index == currentWaypointIndex
            return "\(place.id)-\(skipped)"
        }.joined(separator: "|")

        if coordinator.lastAnnotationSignature != annotationSignature {
            coordinator.lastAnnotationSignature = annotationSignature
            map.removeAnnotations(map.annotations.filter { $0 is RouteAnnotation })
            // Numbered stop annotations (skip current active waypoint — use pulse)
            for (index, place) in routePlaces.enumerated() {
                guard let coord = place.coordinate else { continue }
                if isNavigating && !isPausedAtStop && index == currentWaypointIndex { continue }
                map.addAnnotation(RouteAnnotation(coordinate: coord, title: place.name, index: index + 1))
            }
        }

        // Pulsing annotation for next waypoint: koordinat değişmediyse dokunma
        if isNavigating && !isPausedAtStop, let coord = nextWaypointCoordinate {
            let changed = coordinator.currentNextWaypointCoordinate.map {
                abs($0.latitude - coord.latitude) > 0.0001 || abs($0.longitude - coord.longitude) > 0.0001
            } ?? true
            if changed {
                coordinator.currentNextWaypointCoordinate = coord
                map.removeAnnotations(map.annotations.filter { $0 is NextWaypointAnnotation })
                map.addAnnotation(NextWaypointAnnotation(coordinate: coord))
            }
        } else if coordinator.currentNextWaypointCoordinate != nil {
            coordinator.currentNextWaypointCoordinate = nil
            map.removeAnnotations(map.annotations.filter { $0 is NextWaypointAnnotation })
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var completedSegmentCount: Int = 0
        var currentNextWaypointCoordinate: CLLocationCoordinate2D? = nil
        var lastAppliedRegion: MKCoordinateRegion? = nil
        var lastPolylineIDs: [ObjectIdentifier] = []
        var lastAnnotationSignature: String = ""

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                let overlayIndex = mapView.overlays.firstIndex(where: { $0 === polyline }) ?? 0
                renderer.strokeColor = overlayIndex < completedSegmentCount
                    ? UIColor(PinlyTheme.routeCompleted)
                    : UIColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 1)
                renderer.lineWidth = 5
                renderer.lineDashPattern = [8, 4]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let _ = annotation as? NextWaypointAnnotation {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "nextWaypoint")
                view.frame = CGRect(x: 0, y: 0, width: 48, height: 48)

                let centerDot = CALayer()
                centerDot.frame = CGRect(x: 18, y: 18, width: 12, height: 12)
                centerDot.cornerRadius = 6
                centerDot.backgroundColor = UIColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 1).cgColor
                view.layer.addSublayer(centerDot)

                let pulseRing = CALayer()
                pulseRing.frame = CGRect(x: 4, y: 4, width: 40, height: 40)
                pulseRing.cornerRadius = 20
                pulseRing.borderWidth = 3
                pulseRing.borderColor = UIColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 1).cgColor
                pulseRing.opacity = 0
                view.layer.addSublayer(pulseRing)

                let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
                scaleAnim.values = [0.5, 1.2, 1.0]
                scaleAnim.keyTimes = [0, 0.7, 1.0]

                let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
                opacityAnim.values = [0.8, 0.3, 0.0]
                opacityAnim.keyTimes = [0, 0.7, 1.0]

                let animGroup = CAAnimationGroup()
                animGroup.animations = [scaleAnim, opacityAnim]
                animGroup.duration = 1.5
                animGroup.repeatCount = .infinity
                pulseRing.add(animGroup, forKey: "pulse")

                return view
            }

            if let routeAnnotation = annotation as? RouteAnnotation {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "route")
                view.glyphText = "\(routeAnnotation.index)"
                view.markerTintColor = UIColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 1)
                view.titleVisibility = .visible
                return view
            }

            return nil
        }
    }
}

// MARK: - Annotations

class RouteAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let index: Int

    init(coordinate: CLLocationCoordinate2D, title: String, index: Int) {
        self.coordinate = coordinate
        self.title = title
        self.index = index
    }
}

class NextWaypointAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String? = nil

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
