// Pinly app icon üretici — 1024×1024 light/dark/tinted PNG
// Çalıştırma: swift scripts/generate_icon.swift
import AppKit

let size = 1024
let outDir = "Pinly/Assets.xcassets/AppIcon.appiconset"

// Marka renkleri — "Doğal" palet (çam yeşili + ılık kâğıt)
let coral    = CGColor(red: 0.17, green: 0.36, blue: 0.27, alpha: 1)   // çam koyu #2C5C45
let coralW   = CGColor(red: 0.24, green: 0.47, blue: 0.35, alpha: 1)   // çam açık #3D7859
let navy     = CGColor(red: 0.078, green: 0.106, blue: 0.090, alpha: 1) // is #141B17
let navyL    = CGColor(red: 0.118, green: 0.165, blue: 0.137, alpha: 1) // is açık #1E2A23
let white    = CGColor(red: 0.985, green: 0.975, blue: 0.955, alpha: 1) // ılık beyaz

enum Variant { case light, dark, tinted }

func drawPinPath(_ ctx: CGContext) -> CGPath {
    // Klasik harita pini: daire + daireye gömülü kuyruk üçgeni (union görünümü)
    let path = CGMutablePath()
    let center = CGPoint(x: 512, y: 590)
    let r: CGFloat = 235
    path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    // Üçgen, elipsle AYNI sarım yönünde olmalı — aksi halde nonzero winding
    // kesişim bölgesini iptal edip pin'i oyuyor
    let apex = CGPoint(x: 512, y: 195)
    path.move(to: apex)
    path.addLine(to: CGPoint(x: center.x + 155, y: center.y - 130))
    path.addLine(to: CGPoint(x: center.x - 155, y: center.y - 130))
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

    // Zemin
    switch variant {
    case .light:
        let grad = CGGradient(colorsSpace: nil, colors: [coralW, coral] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
    case .dark:
        let grad = CGGradient(colorsSpace: nil, colors: [navyL, navy] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0), options: [])
    case .tinted:
        break // şeffaf zemin + grayscale içerik
    }

    // Yürüyüş rotası — pinin altından geçen kesikli kavis
    let routeColor: CGColor
    switch variant {
    case .light:  routeColor = CGColor(red: 0.93, green: 0.90, blue: 0.80, alpha: 0.50) // kum
    case .dark:   routeColor = CGColor(red: 0.42, green: 0.66, blue: 0.52, alpha: 0.50) // çam açık
    case .tinted: routeColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.5)
    }
    let route = CGMutablePath()
    route.move(to: CGPoint(x: 150, y: 330))
    route.addQuadCurve(to: CGPoint(x: 874, y: 330), control: CGPoint(x: 512, y: 60))
    ctx.setStrokeColor(routeColor)
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [52, 46])
    ctx.addPath(route)
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    // Rota uç noktaları
    ctx.setFillColor(routeColor)
    ctx.fillEllipse(in: CGRect(x: 150 - 27, y: 330 - 27, width: 54, height: 54))
    ctx.fillEllipse(in: CGRect(x: 874 - 27, y: 330 - 27, width: 54, height: 54))

    // Pin gölgesi (light/dark)
    if variant != .tinted {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 60,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.30))
        let pinColor: CGColor = variant == .light ? white : coral
        ctx.setFillColor(pinColor)
        ctx.addPath(drawPinPath(ctx))
        ctx.fillPath()
        ctx.restoreGState()
    } else {
        ctx.setFillColor(white)
        ctx.addPath(drawPinPath(ctx))
        ctx.fillPath()
    }

    // Dark varyantta pine gradient ver
    if variant == .dark {
        ctx.saveGState()
        ctx.addPath(drawPinPath(ctx))
        ctx.clip()
        let grad = CGGradient(colorsSpace: nil, colors: [coralW, coral] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 300, y: 850), end: CGPoint(x: 720, y: 200), options: [])
        ctx.restoreGState()
    }

    // Pin göbeği (delik)
    ctx.setBlendMode(.clear)
    let holeR: CGFloat = 100
    ctx.fillEllipse(in: CGRect(x: 512 - holeR, y: 590 - holeR, width: holeR * 2, height: holeR * 2))
    ctx.setBlendMode(.normal)
    // Tinted/dark'ta delik zemin rengini göstersin diye zemini geri doldur
    if variant == .light {
        // delik gradient zemini gösteriyor — ekstra iş yok (clear yeterli olurdu ama
        // App Store ikonu opak olmalı; deliği zemin rengiyle doldur)
        let grad = CGGradient(colorsSpace: nil, colors: [coralW, coral] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: 512 - holeR, y: 590 - holeR, width: holeR * 2, height: holeR * 2))
        ctx.clip()
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
        ctx.restoreGState()
    } else if variant == .dark {
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: 512 - holeR, y: 590 - holeR, width: holeR * 2, height: holeR * 2))
        ctx.clip()
        let grad = CGGradient(colorsSpace: nil, colors: [navyL, navy] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0), options: [])
        ctx.restoreGState()
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
