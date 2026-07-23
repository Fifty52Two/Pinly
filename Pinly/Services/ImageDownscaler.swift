import Foundation
import UIKit

// MARK: - ImageDownscaler
//
// `PlacePhotoStore` ve `RouteMemoryStore` aynı küçültme+sıkıştırma sabitlerini
// paylaşır (1200px uzun kenar, 0.8 JPEG kalitesi) — burada tek yerde tutulur,
// kopyalanmaz.

enum ImageDownscaler {
    /// Görseli en fazla `maxSide` uzun kenara küçültüp JPEG olarak sıkıştırır.
    /// `format.scale = 1` ŞART: verilmezse `UIGraphicsImageRenderer` ana ekranın
    /// scale'ini (2x/3x) kullanır — newSize noktada `maxSide` olsa bile gerçek
    /// cihazda çıktı piksel cinsinden 2-3 katına çıkar, sınır sessizce delinir.
    static func downscaledJPEGData(
        _ image: UIImage,
        maxSide: CGFloat = 1200,
        quality: CGFloat = 0.8
    ) -> Data? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale,
                             height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
