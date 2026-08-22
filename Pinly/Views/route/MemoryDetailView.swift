import SwiftUI
import UIKit

// MARK: - MemoryDetailView
//
// Günlük'te foto'lu bir RouteHistory kartına dokununca açılır: tüm anı
// fotoğrafları + istatistikler + duraklar + "Yeniden Paylaş". Bu akışta harita
// İZİ YOKTUR — `RouteHistory` koordinat saklamaz (bkz. RouteMemoryMapSnapshotter
// yorumu), kart yine de `mapSnapshot: nil` ile üretilir.

struct MemoryDetailView: View {
    let history: RouteHistory
    let routeMemories: RouteMemoryStoring

    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics
    @Environment(\.colorScheme) private var colorScheme
    @State private var showShareFormatPicker = false

    private var loadedPhotos: [UIImage] {
        history.memoryPhotos.compactMap { routeMemories.load(fileName: $0.fileName) }
    }

    var body: some View {
        // ÖNEMLİ: kendi NavigationStack'ini SARMAZ — RouteHistoryView'in
        // navigationDestination(for:) ile push ettiği hedef budur; iç içe
        // NavigationStack .zoom geçişini kırar (bkz. specs/FAZ6_UI_YON.md Wow #2).
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroBanner

                Text(history.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // heroBanner zaten ilk fotoğrafı büyük gösteriyor — grid kalan
                // fotoğrafları (varsa) listeler, birinciyi tekrarlamaz.
                if loadedPhotos.count > 1 {
                    photoGrid
                }

                statCard

                if !history.placeNames.isEmpty {
                    stopsCard
                }
            }
            .padding(20)
            .padding(.bottom, 90)
        }
        .background(PinlyTheme.groundGradient)
        .navigationTitle(history.routeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel(NSLocalizedString("Kapat", comment: ""))
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showShareFormatPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(NSLocalizedString("Yeniden Paylaş", comment: ""))
                }
            }
            .buttonStyle(PinlyPrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .background(.regularMaterial)
        }
        .confirmationDialog(
            NSLocalizedString("Yeniden Paylaş", comment: ""),
            isPresented: $showShareFormatPicker,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Hikaye (9:16)", comment: "")) { share(format: .story) }
            Button(NSLocalizedString("Gönderi (4:5)", comment: "")) { share(format: .post) }
            Button(NSLocalizedString("İptal", comment: ""), role: .cancel) {}
        }
    }

    // Claude Design "Pinly Seigaiha Uygulama" mockup'ındaki (26 · Anı detayı) hero
    // banner — foto varsa ilk anı fotoğrafı, yoksa primaryWarm + gerçek seigaiha
    // dokusu (birebir; önceden bu banner hiç yoktu).
    @ViewBuilder
    private var heroBanner: some View {
        if let first = loadedPhotos.first {
            Image(uiImage: first)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            ZStack {
                PinlyTheme.primaryWarm
                GeometryReader { geo in
                    Image(PinlyTheme.seigaihaLinesOnInk(colorScheme))
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(Rectangle())
                }
                .opacity(0.35)
                .allowsHitTesting(false)
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var photoGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(loadedPhotos.dropFirst().enumerated()), id: \.offset) { _, image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var statCard: some View {
        HStack(spacing: 24) {
            StatChip(value: history.formattedDistance, label: NSLocalizedString("Mesafe", comment: ""), icon: "figure.walk", color: PinlyTheme.primary)
            StatChip(value: history.formattedDuration, label: NSLocalizedString("Süre", comment: ""), icon: "clock", color: PinlyTheme.success)
            if history.stepCount > 0 {
                StatChip(value: "\(history.stepCount)", label: NSLocalizedString("Adım", comment: ""), icon: "shoeprints.fill", color: PinlyTheme.warning)
            }
        }
        .pinlyCard()
    }

    private var stopsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("Rotanız", comment: ""))
                .font(.subheadline.weight(.semibold))
            ForEach(Array(history.placeNames.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(PinlyTheme.onAccent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(PinlyTheme.primary))
                    Text(name)
                        .font(.subheadline)
                }
            }
        }
        .pinlyCard()
    }

    private func share(format: MemoryShareFormat) {
        let composer = DefaultMemoryCardComposer.shared
        let image: UIImage
        switch format {
        case .story: image = composer.composeStory(history: history, photos: loadedPhotos, mapSnapshot: nil)
        case .post:  image = composer.composePost(history: history, photos: loadedPhotos, mapSnapshot: nil)
        }
        analytics.track(.memoryCardShared(format: format.rawValue))
        presentShareSheet(image: image)
    }

    private func presentShareSheet(image: UIImage) {
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: \.isKeyWindow)?
            .rootViewController
        var top = rootVC
        while let presented = top?.presentedViewController { top = presented }
        top?.present(av, animated: true)
    }
}
