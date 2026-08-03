// Pinly app icon üretici — 1024×1024 light/dark/tinted PNG
// Çalıştırma: swift scripts/generate_icon.swift
//
// Claude Design "Pinly Seigaiha Uygulama" mockup'ından (2026-08) BİREBİR: tek renk
// zemin + tek glif (pin). "Kalabalık yok" — önceki gradyan/dashed-rota/gölge dolu
// tasarımın yerine geçti. Işık/koyu modda AYNI tasarım (mockup'ın kendisi de tek
// treatment gösteriyor) — Pinly'nin "primary" (#42505E) rengi zaten her iki modda
// da iyi çalışıyor.
import AppKit

let size = 1024
let outDir = "Pinly/Assets.xcassets/AppIcon.appiconset"

// PinlyTheme.primary (açık mod değeri — sabit ikon zemini için kullanılıyor) + krem pin.
let primary = CGColor(red: 0.259, green: 0.314, blue: 0.369, alpha: 1)  // #42505E
let cream   = CGColor(red: 0.941, green: 0.914, blue: 0.863, alpha: 1)  // #F0E9DC
let white   = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

enum Variant { case light, dark, tinted }

/// Mockup'taki pin glifi — 100×100 viewBox'tan 1024×1024'e ölçeklenmiş.
/// Teardrop gövde + göbekte "delik" (arka plan rengiyle boyanan daire) — klasik
/// harita pini silüeti, mockup SVG path'iyle birebir.
func pinBodyPath() -> CGPath {
    let s: CGFloat = 1024.0 / 100.0
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: (100 - y) * s) } // SVG y aşağı, Core Graphics y yukarı
    let path = CGMutablePath()
    path.move(to: p(50, 24))
    path.addCurve(to: p(27, 47), control1: p(37, 24), control2: p(27, 34))
    path.addCurve(to: p(50, 84), control1: p(27, 64), control2: p(50, 84))
    path.addCurve(to: p(73, 47), control1: p(50, 84), control2: p(73, 64))
    path.addCurve(to: p(50, 24), control1: p(73, 34), control2: p(63, 24))
    path.closeSubpath()
    return path
}

func render(_ variant: Variant, filename: String) {
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("context") }

    let full = CGRect(x: 0, y: 0, width: size, height: size)

    switch variant {
    case .light, .dark:
        // Mockup: ışık/koyu modda AYNI tek-renk zemin — bilinçli, "tek renk tek glif"
        // sadeliği ikisinde de korunur.
        ctx.setFillColor(primary)
        ctx.fill(full)
    case .tinted:
        break // şeffaf zemin, sistem kendi tonunu uygular
    }

    let pinPath = pinBodyPath()
    let s: CGFloat = 1024.0 / 100.0
    let holeCenter = CGPoint(x: 50 * s, y: (100 - 47) * s)
    let holeR: CGFloat = 10.5 * s

    switch variant {
    case .light, .dark:
        ctx.setFillColor(cream)
        ctx.addPath(pinPath)
        ctx.fillPath()
        // Göbek deliği — zemin rengiyle "oyulmuş" görünüm
        ctx.setFillColor(primary)
        ctx.fillEllipse(in: CGRect(x: holeCenter.x - holeR, y: holeCenter.y - holeR, width: holeR * 2, height: holeR * 2))
    case .tinted:
        // Tek glif, beyaz, şeffaf zemin üstünde — sistem kendi tint'ini uygular.
        ctx.setFillColor(white)
        ctx.addPath(pinPath)
        ctx.fillPath()
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: CGRect(x: holeCenter.x - holeR, y: holeCenter.y - holeR, width: holeR * 2, height: holeR * 2))
        ctx.setBlendMode(.normal)
    }

    guard let image = ctx.makeImage() else { fatalError("image") }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
    let url = URL(fileURLWithPath: "\(outDir)/\(filename)")
    try! data.write(to: url)
    print("✓ \(filename)")
}

render(.light,  filename: "icon-light.png")
render(.dark,   filename: "icon-dark.png")
render(.tinted, filename: "icon-tinted.png")
