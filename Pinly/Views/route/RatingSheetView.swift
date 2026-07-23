import SwiftUI
import SwiftData
import PhotosUI
// MARK: - Rating Sheet

struct RatingSheetView: View {
    let place: Place
    /// Bu durak için bu oturumda ZATEN kaç anı fotoğrafı eklendi (max 3).
    let existingPhotoCount: Int
    let placeStore: PlaceRepository
    let modelContext: ModelContext
    /// Kullanıcı fotoğraf seçtiğinde/çektiğinde tetiklenir — (görsel, mekan
    /// fotoğrafı olarak da kaydedilsin mi). Disk IO burada YAPILMAZ, ViewModel'e
    /// devredilir (`RouteSummaryViewModel.addMemoryPhoto`).
    let onPhotoPicked: (UIImage, Bool) -> Void
    let onDismiss: () -> Void

    @State private var selectedRating: Int = 0
    @State private var capturedThisSession = 0
    @State private var saveAsPlacePhoto = true
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showCamera = false

    private var totalPhotoCount: Int { existingPhotoCount + capturedThisSession }
    private var canAddMorePhotos: Bool { totalPhotoCount < 3 }
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("Nasıldı?", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(place.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedRating = star
                        }
                    } label: {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundColor(star <= selectedRating ? PinlyTheme.ratingStar : .secondary)
                            .scaleEffect(star <= selectedRating ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedRating)
                    }
                    .buttonStyle(.plain)
                }
            }

            memoryPhotoSection
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                Button(NSLocalizedString("Atla", comment: "")) {
                    onDismiss()
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PinlyTheme.fillMuted)
                .cornerRadius(12)

                Button(NSLocalizedString("Kaydet", comment: "")) {
                    if selectedRating > 0 {
                        place.userRating = selectedRating
                        placeStore.save(context: modelContext)
                    }
                    onDismiss()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedRating > 0 ? PinlyTheme.primary : Color.gray)
                .cornerRadius(12)
                .disabled(selectedRating == 0)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .presentationDetents([.height(canAddMorePhotos ? 420 : 360)])
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    await MainActor.run {
                        capturedThisSession += 1
                        onPhotoPicked(picked, saveAsPlacePhoto)
                        pickerItem = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picked in
                capturedThisSession += 1
                onPhotoPicked(picked, saveAsPlacePhoto)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var memoryPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("Fotoğraf ekle", comment: ""))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if totalPhotoCount > 0 {
                    Text("\(totalPhotoCount)/3")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if canAddMorePhotos {
                HStack(spacing: 24) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(NSLocalizedString("Fotoğraf Ekle", comment: ""), systemImage: "photo.badge.plus")
                    }
                    if cameraAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label(NSLocalizedString("Fotoğraf Çek", comment: ""), systemImage: "camera")
                        }
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(PinlyTheme.primary)
            }

            Toggle(NSLocalizedString("Mekan fotoğrafı olarak da kaydet", comment: ""), isOn: $saveAsPlacePhoto)
                .font(.caption)
                .tint(PinlyTheme.primary)
        }
    }
}
