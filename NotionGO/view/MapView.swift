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

    @AppStorage("appTheme") private var storedTheme = "light"

    @State private var showRouteFlow = false
    @State private var selectedPlace: Place? = nil
    @State private var showAddPlace = false
    @State private var navigateToSinglePlace = false
    @State private var editingPlace: Place? = nil

    private var t: ThemeColors { ThemeColors.make(storedTheme) }

    var visiblePlaces: [Place] { placeStore.places.filter { $0.coordinate != nil } }

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
                    t: t,
                    onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedPlace = nil }
                    },
                    onNavigate: {
                        routeManager.reset()
                        let key = place.id.uuidString
                        routeManager.selectedCategories = [key]
                        routeManager.selectedPlaces[key] = place
                        selectedPlace = nil
                        navigateToSinglePlace = true
                    },
                    onEdit: { selectedPlace = nil; editingPlace = place },
                    onDelete: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedPlace = nil }
                        placeStore.deletePlace(place, context: modelContext)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 110)
            }

            // Route button
            if selectedPlace == nil {
                Button {
                    showRouteFlow = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Rota Oluştur")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(t.buttonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(t.accent)
                    .clipShape(Capsule())
                    .shadow(color: t.accent.opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }

            // Top overlay buttons
            VStack {
                HStack(alignment: .top) {
                    // Back
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(t.title)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 6)
                    }
                    .padding(.top, 60)
                    .padding(.leading, 16)

                    if !locationManager.currentDistrict.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill").font(.system(size: 10))
                            Text(locationManager.currentDistrict).font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(t.title)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 6)
                        .padding(.top, 66)
                        .padding(.leading, 8)
                    }

                    Spacer()

                    // Add place
                    Button { showAddPlace = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(t.buttonText)
                            .padding(12)
                            .background(t.accent)
                            .clipShape(Circle())
                            .shadow(color: t.accent.opacity(0.4), radius: 8)
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
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Kapat") {
                                navigateToSinglePlace = false
                                routeManager.reset()
                            }
                            .foregroundColor(t.primary)
                        }
                    }
            }
        }
        .sheet(isPresented: $showAddPlace) {
            AddPlaceView().environmentObject(placeStore)
        }
        .sheet(item: $editingPlace) { place in
            EditPlaceView(place: place).environmentObject(placeStore)
        }
    }
}

// MARK: - UIViewRepresentable Map

struct MainMapView: UIViewRepresentable {
    let places: [Place]
    let userLocation: CLLocation?
    @Binding var selectedPlace: Place?

    func makeCoordinator() -> Coordinator { Coordinator(selectedPlace: $selectedPlace) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "place")
        if let loc = userLocation {
            map.setRegion(MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)), animated: false)
        } else {
            map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)), animated: false)
        }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        if let loc = userLocation, !context.coordinator.hasZoomed {
            context.coordinator.hasZoomed = true
            map.setRegion(MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)), animated: true)
        }
        let currentIds = Set(map.annotations.compactMap { ($0 as? PlaceAnnotation)?.placeId })
        let newIds = Set(places.compactMap { $0.coordinate != nil ? $0.id.uuidString : nil })
        guard currentIds != newIds else { return }
        map.removeAnnotations(map.annotations.filter { $0 is PlaceAnnotation })
        for place in places {
            guard let coord = place.coordinate else { continue }
            map.addAnnotation(PlaceAnnotation(place: place, coordinate: coord))
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var selectedPlace: Place?
        var hasZoomed = false

        init(selectedPlace: Binding<Place?>) { _selectedPlace = selectedPlace }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let placeAnnotation = annotation as? PlaceAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "place", for: annotation) as! MKMarkerAnnotationView
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
            DispatchQueue.main.async { self.selectedPlace = placeAnnotation.place }
        }
    }
}

// MARK: - Place Annotation

class PlaceAnnotation: NSObject, MKAnnotation {
    let place: Place
    let coordinate: CLLocationCoordinate2D
    var placeId: String { place.id.uuidString }
    var title: String? { place.name }

    init(place: Place, coordinate: CLLocationCoordinate2D) {
        self.place = place; self.coordinate = coordinate
    }
}

// MARK: - Place Card

struct PlaceCard: View {
    let place: Place
    let t: ThemeColors
    let onDismiss: () -> Void
    let onNavigate: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var showDeleteConfirm = false

    init(
        place: Place, t: ThemeColors,
        onDismiss: @escaping () -> Void,
        onNavigate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.place = place; self.t = t
        self.onDismiss = onDismiss; self.onNavigate = onNavigate
        self.onEdit = onEdit; self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(place.categoryColor.opacity(0.18)).frame(width: 40, height: 40)
                    Image(systemName: place.categoryIcon).font(.system(size: 16)).foregroundColor(place.categoryColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundColor(t.title).lineLimit(1)
                    Text(place.category).font(.system(size: 11)).foregroundColor(t.subtitle)
                }
                Spacer()

                if let edit = onEdit {
                    Button(action: edit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                            .foregroundColor(t.primary)
                            .padding(7)
                            .background(Circle().fill(t.accent.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
                if onDelete != nil {
                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(t.destructive)
                            .padding(7)
                            .background(Circle().fill(t.destructive.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(t.subtitle)
                        .padding(7)
                        .background(Circle().fill(t.inputBg))
                }
                .buttonStyle(.plain)
            }

            Label(place.district, systemImage: "mappin")
                .font(.system(size: 11))
                .foregroundColor(t.subtitle.opacity(0.7))

            HStack(spacing: 8) {
                if let rating = place.userRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(star <= rating ? t.accent : t.subtitle.opacity(0.3))
                        }
                    }
                }
                if place.visitCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundColor(t.primary)
                        Text("\(place.visitCount)x ziyaret")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(t.primary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(t.accent.opacity(0.15)))
                }
                Spacer()
            }

            if let navigate = onNavigate {
                Button(action: navigate) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill").font(.system(size: 12))
                        Text("Buraya Git").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(t.buttonText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(t.accent)
                    .clipShape(Capsule())
                    .shadow(color: t.accent.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(t.bg)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(t.cardBorder, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 16)
        .confirmationDialog("Bu mekanı silmek istiyor musun?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Sil", role: .destructive) { onDelete?() }
            Button("İptal", role: .cancel) {}
        }
    }
}
