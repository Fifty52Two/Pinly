import SwiftUI
import MapKit
import SwiftData

// MARK: - Route Flow Dismiss Environment Key

private struct DismissRouteFlowKey: EnvironmentKey {
    static let defaultValue: (() -> Void) = {}
}

extension EnvironmentValues {
    var dismissRouteFlow: () -> Void {
        get { self[DismissRouteFlowKey.self] }
        set { self[DismissRouteFlowKey.self] = newValue }
    }
}

struct MapView: View {
    @EnvironmentObject var placeStore: PlaceStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var routeManager: RouteManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.entitlements) private var entitlements

    @State private var showRouteFlow = false
    @State private var selectedPlace: Place? = nil
    @State private var showAddPlace = false
    @State private var navigateToSinglePlace = false
    @State private var editingPlace: Place? = nil
    @State private var showPaywall = false

    var visiblePlaces: [Place] {
        placeStore.places.filter { $0.coordinate != nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            MainMapView(
                places: visiblePlaces,
                userLocation: locationManager.userLocation,
                selectedPlace: $selectedPlace
            )
            .ignoresSafeArea()

            // Selected place card
            if let place = selectedPlace {
                PlaceCard(
                    place: place,
                    onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedPlace = nil
                        }
                    },
                    onNavigate: {
                        routeManager.setRoute(places: [place], name: place.name)
                        selectedPlace = nil
                        navigateToSinglePlace = true
                    },
                    onEdit: {
                        selectedPlace = nil
                        editingPlace = place
                    },
                    onDelete: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedPlace = nil
                        }
                        placeStore.deletePlace(place, context: modelContext)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 100)
            }

            // Route button
            VStack {
                Spacer()
                Button {
                    showRouteFlow = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "map.fill")
                        Text(NSLocalizedString("Rota Oluştur", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PinlyTheme.primary)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }

            // Top buttons
            VStack {
                HStack(alignment: .top) {
                    // Back to home
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.top, 60)
                    .padding(.leading, 16)

                    if !locationManager.currentDistrict.isEmpty {
                        Label(locationManager.currentDistrict, systemImage: "location.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.top, 66)
                    }
                    Spacer()
                    Button {
                        if entitlements.canAddPlace(currentCount: placeStore.places.count) {
                            showAddPlace = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(PinlyTheme.primary)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showRouteFlow) {
            CategoryPickerView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
                .environmentObject(routeManager)
                .environment(\.dismissRouteFlow, {
                    showRouteFlow = false
                    locationManager.stopNavigationTracking()
                    routeManager.reset()
                })
        }
        .fullScreenCover(isPresented: $navigateToSinglePlace) {
            NavigationStack {
                RouteSummaryView()
                    .environmentObject(placeStore)
                    .environmentObject(locationManager)
                    .environmentObject(routeManager)
                    // RouteSummaryView'in X butonu ve tamamlama overlay'i bu
                    // environment'ı çağırır — set edilmezse kullanıcı ekranda kalır
                    .environment(\.dismissRouteFlow, {
                        navigateToSinglePlace = false
                        locationManager.stopNavigationTracking()
                        routeManager.reset()
                    })
            }
        }
        .sheet(isPresented: $showAddPlace) {
            AddPlaceView()
                .environmentObject(placeStore)
                .environmentObject(locationManager)
        }
        .sheet(item: $editingPlace) { place in
            EditPlaceView(place: place)
                .environmentObject(placeStore)
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
        }
    }
}

// MARK: - UIViewRepresentable Map

struct MainMapView: UIViewRepresentable {
    let places: [Place]
    let userLocation: CLLocation?
    @Binding var selectedPlace: Place?

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedPlace: $selectedPlace)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.mapType = .mutedStandard
        // Register annotation view class for proper reuse
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "place")

        if let loc = userLocation {
            map.setRegion(
                MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)),
                animated: false
            )
        } else {
            map.setRegion(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ),
                animated: false
            )
        }

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Zoom to user on first fix
        if let loc = userLocation, !context.coordinator.hasZoomed {
            context.coordinator.hasZoomed = true
            map.setRegion(
                MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)),
                animated: true
            )
        }

        // Rebuild annotations when the place set changes.
        // Kategori de karşılaştırmaya dahil — düzenlenen mekanın pin rengi/ikonu güncellensin.
        let currentIds = Set(map.annotations.compactMap { ($0 as? PlaceAnnotation)?.placeKey })
        let newIds = Set(places.compactMap { $0.coordinate != nil ? "\($0.id.uuidString)-\($0.category)" : nil })

        guard currentIds != newIds else { return }

        map.removeAnnotations(map.annotations.filter { $0 is PlaceAnnotation })
        for place in places {
            guard let coord = place.coordinate else { continue }
            map.addAnnotation(PlaceAnnotation(place: place, coordinate: coord))
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var selectedPlace: Place?
        var hasZoomed = false

        init(selectedPlace: Binding<Place?>) {
            _selectedPlace = selectedPlace
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let placeAnnotation = annotation as? PlaceAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: "place",
                for: annotation
            ) as! MKMarkerAnnotationView

            view.annotation = annotation
            view.markerTintColor = UIColor(placeAnnotation.place.categoryColor)
            view.glyphImage = UIImage(systemName: placeAnnotation.place.categoryIcon)
            view.titleVisibility = .hidden
            view.canShowCallout = false
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let placeAnnotation = annotation as? PlaceAnnotation else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            DispatchQueue.main.async {
                self.selectedPlace = placeAnnotation.place
            }
        }
    }
}

// MARK: - Place Annotation

class PlaceAnnotation: NSObject, MKAnnotation {
    let place: Place
    let coordinate: CLLocationCoordinate2D
    var placeId: String { place.id.uuidString }
    var placeKey: String { "\(place.id.uuidString)-\(place.category)" }
    var title: String? { place.name }

    init(place: Place, coordinate: CLLocationCoordinate2D) {
        self.place = place
        self.coordinate = coordinate
    }
}

// MARK: - Place Card

struct PlaceCard: View {
    let place: Place
    let onDismiss: () -> Void
    let onNavigate: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var showDeleteConfirm = false
    @State private var showShare = false

    init(
        place: Place,
        onDismiss: @escaping () -> Void,
        onNavigate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.place = place
        self.onDismiss = onDismiss
        self.onNavigate = onNavigate
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header: icon + name + delete + dismiss
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(place.categoryColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: place.categoryIcon)
                        .font(.subheadline)
                        .foregroundColor(place.categoryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(place.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Share button
                Button {
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundColor(.orange.opacity(0.9))
                        .padding(6)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Edit button
                if let edit = onEdit {
                    Button(action: edit) {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundColor(PinlyTheme.slate)
                            .padding(6)
                            .background(PinlyTheme.slate.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Delete button
                if onDelete != nil {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red.opacity(0.7))
                            .padding(6)
                            .background(Color.red.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }

            // District
            Label(place.district, systemImage: "mappin")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Rating + visit count
            HStack(spacing: 8) {
                if let rating = place.userRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundColor(star <= rating ? .yellow : .secondary)
                        }
                    }
                }

                if place.visitCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(String(format: NSLocalizedString("%ldx ziyaret edildi", comment: ""), place.visitCount))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
                Spacer()
            }

            // Navigate Here button
            if let navigate = onNavigate {
                Button(action: navigate) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                        Text(NSLocalizedString("Navigate Here", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(PinlyTheme.primary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
        .confirmationDialog(NSLocalizedString("Bu mekanı silmek istiyor musun?", comment: ""), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(NSLocalizedString("Sil", comment: ""), role: .destructive) {
                onDelete?()
            }
            Button(NSLocalizedString("İptal", comment: ""), role: .cancel) {}
        }
        .sheet(isPresented: $showShare) {
            SharePlaceView(place: place)
        }
    }
}
