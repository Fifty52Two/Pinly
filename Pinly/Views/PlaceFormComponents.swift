import SwiftUI
import PhotosUI

// MARK: - Mekan Formu Bileşenleri
//
// Add/Edit/QuickAdd formlarının ortak, temalı yapı taşları — sistem Form
// yerine kart tabanlı özel tasarım (slate tema). Renkler PinlyTheme'den.

// MARK: Bölüm etiketi

struct PinlyFormLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .tracking(0.8)
    }
}

// MARK: Kart zemini

private struct FormCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(PinlyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}

// MARK: Metin alanı (ikonlu, kart)

struct PinlyField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(PinlyTheme.primary)
                .frame(width: 22)
            TextField(placeholder, text: $text)
                .font(.body)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .modifier(FormCardBackground())
    }
}

// MARK: Not editörü (placeholder'lı kart)

struct PinlyNotesEditor: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(height: 110)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(.placeholderText))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .modifier(FormCardBackground())
    }
}

// MARK: Kategori çip ızgarası

struct PinlyCategoryGrid: View {
    @Binding var selection: String

    private let columns = [GridItem(.flexible()), GridItem(.flexible()),
                           GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(PlaceCategory.allCases, id: \.rawValue) { cat in
                let isSelected = PlaceCategory.from(selection) == cat
                Button {
                    selection = cat.rawValue
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(isSelected ? cat.color : cat.color.opacity(0.14))
                                .frame(width: 40, height: 40)
                            Image(systemName: cat.icon)
                                .font(.body)
                                .foregroundColor(isSelected ? .white : cat.color)
                        }
                        Text(cat.localizedName)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? cat.color.opacity(0.10) : PinlyTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(isSelected ? cat.color : Color.primary.opacity(0.07),
                                                  lineWidth: isSelected ? 1.5 : 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.25), value: isSelected)
            }
        }
    }
}

// MARK: Konum seçeneği kartı

struct PinlyLocationOption: View {
    let icon: String
    let title: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? PinlyTheme.primary : PinlyTheme.primary.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(isActive ? .white : PinlyTheme.primary)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? PinlyTheme.primary.opacity(0.10) : PinlyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isActive ? PinlyTheme.primary : Color.primary.opacity(0.07),
                                          lineWidth: isActive ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: Fotoğraf seçici (Add/Edit form Section içeriği)

/// Mekan fotoğrafı ekleme/değiştirme/kaldırma — sistem Form'un Section'ı
/// içinde kullanılır. Galeri (PhotosPicker) + kamera (UIImagePickerController)
/// seçenekleri sunar. Seçilen görsel `onPicked` ile ViewModel'e iletilir;
/// disk IO burada YAPILMAZ (PlacePhotoStoring kaydetme anında devreye girer).
struct PlacePhotoPickerRow: View {
    let image: UIImage?
    let onPicked: (UIImage) -> Void
    let onRemove: () -> Void

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showCamera = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Group {
            if let image {
                VStack(spacing: 10) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label(NSLocalizedString("Değiştir", comment: ""), systemImage: "photo")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(PinlyTheme.primary)
                        }
                        if cameraAvailable {
                            cameraButton
                        }
                        Spacer()
                        Button(role: .destructive, action: onRemove) {
                            Label(NSLocalizedString("Kaldır", comment: ""), systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text(NSLocalizedString("Fotoğraf Ekle", comment: ""))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(PinlyTheme.primary)
                }
                if cameraAvailable {
                    cameraButton
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    await MainActor.run {
                        onPicked(picked)
                        pickerItem = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picked in
                onPicked(picked)
            }
            .ignoresSafeArea()
        }
    }

    private var cameraButton: some View {
        Button {
            showCamera = true
        } label: {
            HStack {
                Image(systemName: "camera")
                Text(NSLocalizedString("Fotoğraf Çek", comment: ""))
                    .fontWeight(.medium)
            }
            .font(image == nil ? .body : .subheadline.weight(.medium))
            .foregroundColor(PinlyTheme.primary)
        }
    }
}

// MARK: Kamera (UIImagePickerController sarmalayıcısı)

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: Durum satırı ("Mevcut konum kullanılıyor" / "Konum haritadan seçildi")

struct PinlyStatusRow: View {
    let icon: String
    let tint: Color
    let text: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint)
            Text(text)
                .font(.subheadline)
                .foregroundColor(tint)
            Spacer()
            Button(actionTitle, action: action)
                .font(.caption.weight(.semibold))
                .foregroundColor(PinlyTheme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(tint.opacity(0.10))
        )
    }
}
