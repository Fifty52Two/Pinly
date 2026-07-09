import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - QRCodeGenerating

/// Bir metinden QR kod görseli üretir (CoreImage tabanlı).
protocol QRCodeGenerating {
    func generateQRCode(from string: String) -> UIImage?
}

struct DefaultQRCodeGenerator: QRCodeGenerating {
    func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
