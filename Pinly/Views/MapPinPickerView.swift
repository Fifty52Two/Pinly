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

    @StateObject private var viewModel = MapPinPickerViewModel()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var centerCoordinate: CLLocationCoordinate2D?
    @State private var isCameraMoving = false

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
                    viewModel.reverseGeocode(context.camera.centerCoordinate)
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
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2) // bilinçli: canlı harita üzerinde yüzen pin

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
                if viewModel.isGeocoding || isCameraMoving {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("...")
                        .foregroundColor(.secondary)
                } else if viewModel.geocodeFailed {
                    Text(NSLocalizedString("Adres bulunamadı", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(viewModel.resolvedAddress)
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
            .disabled(centerCoordinate == nil || isCameraMoving || viewModel.isGeocoding)
            .opacity(centerCoordinate == nil || isCameraMoving || viewModel.isGeocoding ? 0.6 : 1)
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4) // bilinçli: canlı harita üzerinde yüzen panel
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
        viewModel.reverseGeocode(start)
    }

    // MARK: - Onayla

    private func confirm() {
        guard let coord = centerCoordinate else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onConfirm(coord, viewModel.confirmAddress(for: coord))
        dismiss()
    }
}
