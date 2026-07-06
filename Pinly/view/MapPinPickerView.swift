import SwiftUI
import MapKit
import CoreLocation

// MARK: - MapPinPickerView
// "Haritayı pin'in altında kaydır" deseni (Uber/Airbnb tarzı):
// pin ekranın ortasında sabit durur, kullanıcı haritayı kaydırır.
// Kamera durunca merkez koordinat reverse-geocode edilir ve alt kartta gösterilir.

struct MapPinPickerView: View {
    /// Düzenleme modunda mevcut koordinatla başlar
    var initialCoordinate: CLLocationCoordinate2D? = nil
    /// Onaylanınca seçilen koordinat + çözümlenen adres döner
    let onConfirm: (CLLocationCoordinate2D, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var centerCoordinate: CLLocationCoordinate2D?
    @State private var resolvedAddress = ""
    @State private var geocodeFailed = false
    @State private var isGeocoding = false
    @State private var isCameraMoving = false

    private let geocoder = CLGeocoder()

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    centerCoordinate = context.camera.centerCoordinate
                    if !isCameraMoving {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            isCameraMoving = true
                        }
                    }
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    centerCoordinate = context.camera.centerCoordinate
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isCameraMoving = false
                    }
                    reverseGeocode(context.camera.centerCoordinate)
                }
                .ignoresSafeArea(edges: .bottom)

                // Sabit merkez pin — harita altında kayar
                centerPin
                    .allowsHitTesting(false)

                // Alt kart
                VStack {
                    Spacer()
                    bottomCard
                }
            }
            .navigationTitle(NSLocalizedString("Haritada Pinle", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("İptal", comment: "")) { dismiss() }
                }
            }
            .onAppear { setInitialCamera() }
        }
    }

    // MARK: - Merkez Pin

    private var centerPin: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white, PinlyTheme.primary)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

            // Pin çubuğu
            Rectangle()
                .fill(PinlyTheme.primary)
                .frame(width: 3, height: 10)

            // Gölge — pin havadayken küçülür
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: isCameraMoving ? 8 : 14, height: isCameraMoving ? 3 : 5)
        }
        // Kamera hareket ederken pin hafifçe havaya kalkar
        .offset(y: isCameraMoving ? -37 : -27) // pin ucu tam harita merkezinde dursun
    }

    // MARK: - Alt Kart

    private var bottomCard: some View {
        VStack(spacing: 14) {
            Label(
                NSLocalizedString("Konumu ayarlamak için haritayı kaydır", comment: ""),
                systemImage: "hand.draw"
            )
            .font(.caption)
            .foregroundColor(.secondary)

            // Çözümlenen adres
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(PinlyTheme.primary)
                if isGeocoding || isCameraMoving {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("...")
                        .foregroundColor(.secondary)
                } else if geocodeFailed {
                    Text(NSLocalizedString("Adres bulunamadı", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(resolvedAddress)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
                Spacer()
            }
            .frame(minHeight: 40)

            Button {
                confirm()
            } label: {
                Text(NSLocalizedString("Bu Konumu Kullan", comment: ""))
            }
            .buttonStyle(PinlyPrimaryButtonStyle())
            .disabled(centerCoordinate == nil || isCameraMoving || isGeocoding)
            .opacity(centerCoordinate == nil || isCameraMoving || isGeocoding ? 0.6 : 1)
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Başlangıç Kamerası

    private func setInitialCamera() {
        let start: CLLocationCoordinate2D
        if let initial = initialCoordinate {
            start = initial
        } else if let userLoc = locationManager.userLocation {
            start = userLoc.coordinate
        } else {
            // İstanbul varsayılan
            start = CLLocationCoordinate2D(latitude: 41.015137, longitude: 28.979530)
        }
        centerCoordinate = start
        cameraPosition = .region(MKCoordinateRegion(
            center: start,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        reverseGeocode(start)
    }

    // MARK: - Reverse Geocode
    // Sadece kamera durunca (.onEnd) çağrılır — doğal debounce.

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        geocoder.cancelGeocode() // önceki istek sürüyorsa iptal et
        isGeocoding = true
        geocodeFailed = false

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            // İptal edilen istekler sessizce yok sayılır
            if let error = error as? CLError, error.code == .geocodeCanceled { return }

            isGeocoding = false
            if let placemark = placemarks?.first,
               let formatted = Self.formatAddress(placemark) {
                resolvedAddress = formatted
                geocodeFailed = false
            } else {
                resolvedAddress = ""
                geocodeFailed = true
            }
        }
    }

    /// Placemark'tan okunabilir adres üretir
    private static func formatAddress(_ placemark: CLPlacemark) -> String? {
        var parts: [String] = []

        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                parts.append("\(thoroughfare) \(subThoroughfare)")
            } else {
                parts.append(thoroughfare)
            }
        } else if let name = placemark.name {
            parts.append(name)
        }
        if let subLocality = placemark.subLocality, !parts.contains(subLocality) {
            parts.append(subLocality)
        }
        if let locality = placemark.locality, !parts.contains(locality) {
            parts.append(locality)
        }
        if let adminArea = placemark.administrativeArea, !parts.contains(adminArea) {
            parts.append(adminArea)
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Onayla

    private func confirm() {
        guard let coord = centerCoordinate else { return }
        // Adres çözümlenemezse koordinat metni kullan — adres alanı boş kalmasın
        let address = resolvedAddress.isEmpty
            ? String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
            : resolvedAddress
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onConfirm(coord, address)
        dismiss()
    }
}
