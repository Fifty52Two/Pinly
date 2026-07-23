import MapKit
import UIKit

// MARK: - RouteMemoryMapSnapshotter
//
// "Hikayeni Paylaş" anındaki CANLI rota verisinden (routePlaces + routePolylines,
// hâlâ RouteManager'da bellekte) harita izi üretir. `RouteHistory` koordinat
// SAKLAMAZ (sadece `placeNames`), bu yüzden bu snapshot yalnızca rota tamamlanma
// anında, henüz koordinatlar elimizdeyken alınabilir — Günlük'ten "Yeniden
// Paylaş" akışında `mapSnapshot: nil` geçilir (bilinçli, bkz. MemoryDetailView).
//
// `MKMapSnapshotter` overlay ÇİZMEZ — polyline `point(for:)` ile snapshot
// context'ine elle çizilir (bilinen tuzak).
enum RouteMemoryMapSnapshotter {
    static func makeSnapshot(
        places: [Place],
        polylines: [MKPolyline],
        size: CGSize = CGSize(width: 1080, height: 420)
    ) async -> UIImage? {
        let coordinates = places.compactMap(\.coordinate)
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude, maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude, maxLon = coordinates[0].longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        // %20 pad
        let latDelta = max(0.006, (maxLat - minLat) * 1.4)
        let lonDelta = max(0.006, (maxLon - minLon) * 1.4)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = 2
        options.showsBuildings = false

        let snapshotter = MKMapSnapshotter(options: options)
        guard let snapshot = try? await snapshotter.start() else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            snapshot.image.draw(at: .zero)

            let lineColor = UIColor(PinlyTheme.slate)
            ctx.cgContext.setLineCap(.round)
            ctx.cgContext.setLineJoin(.round)
            lineColor.setStroke()
            for polyline in polylines where polyline.pointCount > 1 {
                let points = polyline.points()
                let path = UIBezierPath()
                path.move(to: snapshot.point(for: points[0].coordinate))
                for i in 1..<polyline.pointCount {
                    path.addLine(to: snapshot.point(for: points[i].coordinate))
                }
                path.lineWidth = 5
                path.stroke()
            }

            let dotColor = UIColor(PinlyTheme.navy)
            for (index, place) in places.enumerated() {
                guard let coord = place.coordinate else { continue }
                let point = snapshot.point(for: coord)
                let radius: CGFloat = 10
                let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                dotColor.setFill()
                UIBezierPath(ovalIn: rect).fill()

                let text = "\(index + 1)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: point.x - textSize.width / 2, y: point.y - textSize.height / 2), withAttributes: attrs)
            }
        }
    }
}
