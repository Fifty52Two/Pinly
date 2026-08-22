import SwiftUI
import MapKit
// MARK: - Navigation Map View

struct NavigationMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var routePolylines: [MKPolyline]
    /// Kullanıcı navigasyon sırasında haritayı manuel kaydırırsa true olur;
    /// RouteSummaryView bunu izleyerek "Konuma Dön" butonu gösterir.
    @Binding var userManuallyPanned: Bool
    var breadcrumbPolyline: MKPolyline? = nil
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
        context.coordinator.parent = self
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.breadcrumbPolyline = breadcrumbPolyline
        coordinator.currentWaypointIndex = currentWaypointIndex

        // Camera: follow user with heading during active navigation, manual region otherwise.
        // `userManuallyPanned` true ise kullanıcı kendi kaydırmış — followWithHeading'i
        // yeniden zorlamayız; recenter butonuyla false yapılınca tekrar kilitlenir.
        let shouldTrack = isNavigating && !isPausedAtStop
        if shouldTrack && !userManuallyPanned {
            if map.userTrackingMode != .followWithHeading {
                map.setUserTrackingMode(.followWithHeading, animated: true)
            }
            coordinator.lastAppliedRegion = nil
        } else if !shouldTrack {
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

        // Handle breadcrumb polyline (live user walked track)
        let breadcrumbID = breadcrumbPolyline.map { ObjectIdentifier($0) }
        if coordinator.lastBreadcrumbID != breadcrumbID {
            if let oldBreadcrumb = coordinator.lastBreadcrumbPolyline {
                map.removeOverlay(oldBreadcrumb)
            }
            coordinator.lastBreadcrumbID = breadcrumbID
            coordinator.lastBreadcrumbPolyline = breadcrumbPolyline
            if let breadcrumbPolyline {
                map.addOverlay(breadcrumbPolyline, level: .aboveRoads)
            }
        }

        // Overlay'ler yalnızca polyline seti veya tamamlanan segment sayısı değişince yeniden kurulur
        let completedCount = isPausedAtStop ? currentWaypointIndex + 1 : currentWaypointIndex
        let polylineIDs = routePolylines.map { ObjectIdentifier($0) }
        if coordinator.lastPolylineIDs != polylineIDs || coordinator.completedSegmentCount != completedCount {
            coordinator.completedSegmentCount = completedCount
            coordinator.lastPolylineIDs = polylineIDs
            coordinator.segmentIndexByPolylineID.removeAll()
            for (index, polyline) in routePolylines.enumerated() where polyline.pointCount > 0 {
                coordinator.segmentIndexByPolylineID[ObjectIdentifier(polyline)] = index
            }
            map.removeOverlays(map.overlays.filter { overlay in
                if let lastBC = coordinator.lastBreadcrumbPolyline, overlay === lastBC { return false }
                return true
            })
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
            for (index, place) in routePlaces.enumerated() {
                guard let coord = place.coordinate else { continue }
                if isNavigating && !isPausedAtStop && index == currentWaypointIndex { continue }
                map.addAnnotation(RouteAnnotation(coordinate: coord, title: place.name, index: index + 1))
            }
        }

        // Pulsing annotation for next waypoint
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
        var parent: NavigationMapView?
        var completedSegmentCount: Int = 0
        var currentWaypointIndex: Int = 0
        var breadcrumbPolyline: MKPolyline? = nil
        var lastBreadcrumbID: ObjectIdentifier? = nil
        var lastBreadcrumbPolyline: MKPolyline? = nil
        var currentNextWaypointCoordinate: CLLocationCoordinate2D? = nil
        var lastAppliedRegion: MKCoordinateRegion? = nil
        var lastPolylineIDs: [ObjectIdentifier] = []
        var lastAnnotationSignature: String = ""
        var segmentIndexByPolylineID: [ObjectIdentifier: Int] = [:]

        /// Kullanıcı navigasyon sırasında haritayı elle kaydırınca MapKit tracking modunu
        /// .none'a düşürür. Bu delegate bunu yakalar ve recenter butonunu göstermek için
        /// SwiftUI tarafına bildirir.
        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            guard mode == .none,
                  let p = parent, p.isNavigating, !p.isPausedAtStop else { return }
            DispatchQueue.main.async {
                p.userManuallyPanned = true
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                // Check if this overlay is the live breadcrumb polyline
                if let bc = lastBreadcrumbPolyline, polyline === bc {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = UIColor(PinlyTheme.gold) // Canlı yürünen iz (Canlı Altın/Turuncu iz)
                    renderer.lineWidth = 4
                    renderer.lineDashPattern = nil // Solid line
                    return renderer
                }

                let renderer = MKPolylineRenderer(polyline: polyline)
                let segmentIndex = segmentIndexByPolylineID[ObjectIdentifier(polyline)] ?? 0
                
                // 3-Tier segment styling: Completed, Active Current, Future Upcoming
                if segmentIndex < completedSegmentCount {
                    renderer.strokeColor = UIColor(PinlyTheme.routeCompleted) // Yeşilimsi tamamlanan
                    renderer.lineWidth = 4
                } else if segmentIndex == currentWaypointIndex {
                    renderer.strokeColor = UIColor(PinlyTheme.primary) // Parlak aktif accent mavi
                    renderer.lineWidth = 6
                } else {
                    renderer.strokeColor = UIColor(PinlyTheme.primary).withAlphaComponent(0.40) // Soluk gelecek segment
                    renderer.lineWidth = 4
                }
                renderer.lineDashPattern = nil // DÜZ ÇİZGİ — no dash pattern
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

                // Ortak animasyon: MapPinAnimator — MapView'in pin drop/nefes
                // animasyonuyla AYNI kod yolu (specs/FAZ6_UI_YON.md Wow #3-4).
                if let animGroup = MapPinAnimator.ringPulseAnimationGroup() {
                    pulseRing.add(animGroup, forKey: "pulse")
                }

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
