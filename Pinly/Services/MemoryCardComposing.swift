import SwiftUI
import UIKit

// MARK: - MemoryCardComposing
//
// Rota tamamlama "anı kartı" üretimi — `RouteShareCardView` deseninin devamı:
// ImageRenderer ile SwiftUI view'ı görsele çevirir. İki format: dikey "story"
// (1080×1920, Instagram/TikTok hikaye) ve "post" (1080×1350, klasik gönderi).
// Harita izi zaten render edilmiş `mapSnapshot` olarak parametre alınır (bkz.
// `RouteMemoryMapSnapshotter`) — nil olabilir (eski/kayıtlı rotalarda koordinat
// yoksa), kart bu durumda da üretilmelidir.

protocol MemoryCardComposing {
    @MainActor func composeStory(history: RouteHistory, photos: [UIImage], mapSnapshot: UIImage?) -> UIImage
    @MainActor func composePost(history: RouteHistory, photos: [UIImage], mapSnapshot: UIImage?) -> UIImage
}

/// Paylaşım hedefine göre kart formatı — analytics `memory_card_shared.format`
/// parametresiyle aynı ham değerleri kullanır.
enum MemoryShareFormat: String {
    case story
    case post
}

// MARK: - DefaultMemoryCardComposer

final class DefaultMemoryCardComposer: MemoryCardComposing {
    static let shared = DefaultMemoryCardComposer()

    @MainActor
    func composeStory(history: RouteHistory, photos: [UIImage], mapSnapshot: UIImage?) -> UIImage {
        render(MemoryCardView(history: history, photos: photos, mapSnapshot: mapSnapshot, format: .story))
    }

    @MainActor
    func composePost(history: RouteHistory, photos: [UIImage], mapSnapshot: UIImage?) -> UIImage {
        render(MemoryCardView(history: history, photos: photos, mapSnapshot: mapSnapshot, format: .post))
    }

    @MainActor
    private func render(_ view: MemoryCardView) -> UIImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - Kart Boyutları

private enum MemoryCardFormat {
    case story  // ImageRenderer scale=2 → 1080×1920
    case post   // ImageRenderer scale=2 → 1080×1350

    var size: CGSize {
        switch self {
        case .story: return CGSize(width: 540, height: 960)
        case .post:  return CGSize(width: 540, height: 675)
        }
    }
}

// MARK: - MemoryCardView

private struct MemoryCardView: View {
    let history: RouteHistory
    let photos: [UIImage]
    let mapSnapshot: UIImage?
    let format: MemoryCardFormat

    private var dateText: String {
        history.date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mapSection
            VStack(alignment: .leading, spacing: 18) {
                photoSection
                Spacer(minLength: 0)
                footerSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 18)
            .padding(.bottom, 26)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: format.size.width, height: format.size.height)
        .background(PinlyTheme.nightGradient)
    }

    private var mapHeight: CGFloat { format.size.height / 3 }

    @ViewBuilder
    private var mapSection: some View {
        ZStack {
            if let mapSnapshot {
                Image(uiImage: mapSnapshot)
                    .resizable()
                    .scaledToFill()
            } else {
                PinlyTheme.groundGradient
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .frame(width: format.size.width, height: mapHeight)
        .clipped()
    }

    @ViewBuilder
    private var photoSection: some View {
        if !photos.isEmpty {
            if photos.count == 1 {
                Image(uiImage: photos[0])
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                let shown = Array(photos.prefix(4))
                let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { index, photo in
                        ZStack {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            if index == 3, photos.count > 4 {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.black.opacity(0.45))
                                Text("+\(photos.count - 4)")
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white, PinlyTheme.navy)
                Text("Pinly")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(dateText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            Text(history.routeName)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)

            HStack(spacing: 20) {
                MemoryCardStat(value: history.formattedDistance, label: NSLocalizedString("Mesafe", comment: ""))
                MemoryCardStat(value: history.formattedDuration, label: NSLocalizedString("Süre", comment: ""))
                if history.stepCount > 0 {
                    MemoryCardStat(value: "\(history.stepCount)", label: NSLocalizedString("Adım", comment: ""))
                }
            }
        }
    }
}

private struct MemoryCardStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
    }
}
