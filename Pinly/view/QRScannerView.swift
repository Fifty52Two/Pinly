import SwiftUI
import AVFoundation

// MARK: - QR Scanner View

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var placeStore: PlaceStore
    @Environment(\.modelContext) private var modelContext

    @State private var importData: PlaceImportData? = nil
    @State private var showImportConfirm = false
    @State private var isSaving = false
    @State private var cameraPermissionDenied = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraPermissionDenied {
                    CameraPermissionDeniedView()
                } else {
                    CameraPreviewView(onCodeDetected: { url in
                        guard importData == nil else { return }
                        if let data = PlaceImporter.parse(url: url) {
                            importData = data
                            showImportConfirm = true
                        }
                    }, onPermissionDenied: {
                        cameraPermissionDenied = true
                    })
                    .ignoresSafeArea()

                    // Kılavuz çerçeve
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.8), lineWidth: 3)
                            .frame(width: 240, height: 240)
                            .shadow(color: .white.opacity(0.3), radius: 8)
                        Text("QR kodu çerçeve içine al")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.top, 24)
                        Spacer()
                    }
                }
            }
            .navigationTitle("QR ile Mekan Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(isPresented: $showImportConfirm, onDismiss: {
                importData = nil
            }) {
                if let data = importData {
                    ImportConfirmView(
                        data: data,
                        isSaving: $isSaving,
                        onConfirm: {
                            importPlace(data)
                        },
                        onCancel: {
                            importData = nil
                            showImportConfirm = false
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
            }
        }
    }

    private func importPlace(_ data: PlaceImportData) {
        guard FreemiumManager.canAddPlace(currentCount: placeStore.places.count) else {
            showImportConfirm = false
            showPaywall = true
            return
        }
        isSaving = true
        Task {
            await PlaceImporter.save(data, placeStore: placeStore, context: modelContext)
            await MainActor.run {
                isSaving = false
                showImportConfirm = false
                dismiss()
            }
        }
    }
}

// MARK: - Import Confirm Sheet

struct ImportConfirmView: View {
    let data: PlaceImportData
    @Binding var isSaving: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                let cat = PlaceCategory.from(data.category)
                ZStack {
                    Circle()
                        .fill(cat.color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: cat.icon)
                        .font(.title2)
                        .foregroundColor(cat.color)
                }
                Text("Bu mekanı eklemek ister misin?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 10) {
                InfoRow(label: "Mekan", value: data.name)
                InfoRow(label: "Kategori", value: PlaceCategory.from(data.category).localizedName)
                if !data.address.isEmpty {
                    InfoRow(label: "Adres", value: data.address)
                }
                if !data.notes.isEmpty {
                    InfoRow(label: "Not", value: data.notes)
                }
            }
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button("İptal", action: onCancel)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                Button {
                    onConfirm()
                } label: {
                    if isSaving {
                        ProgressView().scaleEffect(0.9)
                    } else {
                        Text("Ekle")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
                .disabled(isSaving)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    let onCodeDetected: (URL) -> Void
    let onPermissionDenied: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeDetected: onCodeDetected, onPermissionDenied: onPermissionDenied)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        context.coordinator.setupSession(in: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stopSession()
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeDetected: (URL) -> Void
        let onPermissionDenied: () -> Void
        private var session: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?

        init(onCodeDetected: @escaping (URL) -> Void, onPermissionDenied: @escaping () -> Void) {
            self.onCodeDetected = onCodeDetected
            self.onPermissionDenied = onPermissionDenied
        }

        func stopSession() {
            session?.stopRunning()
            session = nil
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil
        }

        func setupSession(in view: UIView) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                startCapture(in: view)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if granted { self.startCapture(in: view) }
                        else { self.onPermissionDenied() }
                    }
                }
            default:
                DispatchQueue.main.async { self.onPermissionDenied() }
            }
        }

        private func startCapture(in view: UIView) {
            let session = AVCaptureSession()
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
            self.session = session

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                previewLayer.frame = view.bounds
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let object = objects.first as? AVMetadataMachineReadableCodeObject,
                  let string = object.stringValue,
                  let url = URL(string: string),
                ["pinly", "notiongo"].contains(url.scheme ?? "") else { return }
            session?.stopRunning()
            onCodeDetected(url)
        }
    }
}

// MARK: - Camera Permission Denied

private struct CameraPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Kamera İzni Gerekli")
                .font(.title3)
                .fontWeight(.bold)
            Text("Ayarlar > Pinly > Kamera bölümünden izin ver.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Ayarlara Git")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
    }
}
