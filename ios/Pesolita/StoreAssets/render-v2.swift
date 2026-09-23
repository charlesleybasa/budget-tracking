import AppKit
import CoreText

// Pesolita App Store screenshots, v2 — one continuous panorama sliced into panels.
//
//   ./capture.sh <Pesolita.app>     # raw app screens → raw/
//   swift render-v2.swift           # panels → AppStore-v2/iphone-6.9 and iphone-6.5
//
// Every panel shows the real app (captured from the Debug build with the store wallet), in the
// app's own typeface and colours: ink, Pesolita gold, blue. The background, glows and the gold
// ribbon run across panel edges so the gallery reads as one piece when swiped.
//
// App Store rules kept here on purpose: real app screens in every panel; no prices (they differ
// by country); the Pro panel says it is an in-app purchase; no bank or brand names or logos
// (the store wallet uses Pesolita's generated card art); no claims the app can't back up.

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let raw = root.appendingPathComponent("raw")
let W: CGFloat = 1320, H: CGFloat = 2868

CTFontManagerRegisterFontsForURL(root.appendingPathComponent("build/Outfit.ttf") as CFURL, .process, nil)

/// Outfit ships as a variable font, so weight is set on its `wght` axis — a weight trait alone
/// silently falls back to the default instance.
func outfit(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let wght: Double = switch weight {
    case .black: 900
    case .heavy: 800
    case .bold: 700
    case .semibold: 600
    case .medium: 500
    default: 400
    }
    let wghtTag = NSNumber(value: 0x77676874)  // 'wght'
    let descriptor = NSFontDescriptor(fontAttributes: [.name: "Outfit", .variation: [wghtTag: wght]])
    return NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size, weight: weight)
}

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

let ink = rgb(0x0B0B0D), gold = rgb(0xFFCA28), blue = rgb(0x1D6FF2), green = rgb(0x3CCB9A)
let violet = rgb(0x7C3AED), red = rgb(0xF0483E), paper = rgb(0xF5F4F0)

// MARK: - Content

struct Chip { let symbol: String; let tint: NSColor; let title: String; let detail: String; let x: CGFloat; let y: CGFloat }

struct Panel {
    let eyebrow: String
    /// `{…}` marks the words drawn in gold.
    let headline: String
    let body: String
    let shots: [String]
    var tilt: CGFloat = 0
    var chips: [Chip] = []
    var widget = false
}

let panels: [Panel] = [
    Panel(eyebrow: "PESOLITA", headline: "Every peso\n{gets a home.}",
          body: "Cards, e-wallets and cash — one calm wallet you fill in yourself.",
          shots: ["home-dark"]),
    Panel(eyebrow: "NEW  ·  SPLIT BILLS", headline: "Split the bill\n{in one tap.}",
          body: "Evenly, by shares or exact. Only your part counts as spent.",
          shots: ["split-sheet"], tilt: 0,
          chips: [Chip(symbol: "arrow.down.left.circle.fill", tint: green, title: "₱2,880 comes back", detail: "from 4 friends", x: 0.46, y: 2420)]),
    Panel(eyebrow: "NEW  ·  TRIPS & EVENTS", headline: "Trips,\n{totalled for you.}",
          body: "Every spend on the trip, who carried what, and what's still out.",
          shots: ["event"],
          chips: [Chip(symbol: "airplane.circle.fill", tint: blue, title: "4 friends, 1 trip", detail: "₱7,170 still to come back", x: 0.40, y: 2600)]),
    Panel(eyebrow: "OUT WITH FRIENDS", headline: "Know who\n{still owes you.}",
          body: "Everyone in one place, with a friendly reminder a tap away.",
          shots: ["friends-open"],
          chips: [Chip(symbol: "paperplane.circle.fill", tint: violet, title: "Reminder sent", detail: "to JR · ₱2,650", x: 0.04, y: 2480)]),
    Panel(eyebrow: "PAID ME", headline: "Paid back?\n{Slide it home.}",
          body: "The money lands back in the card it came out of.",
          shots: ["settle"],
          chips: [Chip(symbol: "plus.circle.fill", tint: green, title: "+₱2,650 from JR", detail: "back in Main Account", x: 0.05, y: 2560)]),
    Panel(eyebrow: "PESOLITA PRO  ·  IN-APP PURCHASE", headline: "Back up\n{every peso.}",
          body: "Back up with Google and bring your wallet back on any iPhone.",
          shots: ["pro"],
          chips: [Chip(symbol: "icloud.and.arrow.up.fill", tint: blue, title: "Backed up", detail: "photos and receipts too", x: 0.44, y: 1060)]),
    Panel(eyebrow: "LIGHT & DARK", headline: "Light or dark.\n{Always lovely.}",
          body: "Every screen made for both — follows your iPhone or your choice.",
          shots: ["home-light", "home-dark"]),
    Panel(eyebrow: "INSIGHTS", headline: "See where\n{it all went.}",
          body: "A weekly read that makes sense of your spending, in plain words.",
          shots: ["insights"],
          chips: [Chip(symbol: "chart.bar.fill", tint: gold, title: "10 spends this week", detail: "Bills took the lead", x: 0.42, y: 2440)]),
    Panel(eyebrow: "HOME SCREEN WIDGET", headline: "Your balance,\n{at a glance.}",
          body: "Flick between cards and see what's safe to spend today.",
          shots: [],
          chips: [Chip(symbol: "square.grid.2x2.fill", tint: blue, title: "Three sizes", detail: "small, medium and large", x: 0.52, y: 900)],
          widget: true),
]

// MARK: - Drawing helpers (top-left origin)

let N = CGFloat(panels.count)
let PW = W * N
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(PW), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.translateBy(x: 0, y: H)
ctx.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

func loadImage(_ name: String) -> CGImage {
    let url = raw.appendingPathComponent("\(name).png")
    guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("missing raw/\(name).png — run capture.sh first")
    }
    return image
}

func drawImage(_ image: CGImage, in rect: CGRect) {
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
    ctx.restoreGState()
}

func glow(_ color: NSColor, at center: CGPoint, radius: CGFloat, alpha: CGFloat) {
    let g = CGGradient(colorsSpace: space, colors: [color.withAlphaComponent(alpha).cgColor,
                                                    color.withAlphaComponent(0).cgColor] as CFArray,
                       locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

func text(_ string: NSAttributedString, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
    let height = ceil(string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                          options: .usesLineFragmentOrigin).height)
    string.draw(with: CGRect(x: x, y: y, width: width, height: height), options: .usesLineFragmentOrigin)
    return height
}

/// A phone: black body, thin light edge, the screen inset with matching corners.
func phone(_ shot: CGImage, center: CGPoint, width: CGFloat, top: CGFloat, tilt: CGFloat) {
    let bezel = width * 0.028
    let screenW = width - bezel * 2
    let screenH = screenW * CGFloat(shot.height) / CGFloat(shot.width)
    let body = CGRect(x: -width / 2, y: 0, width: width, height: screenH + bezel * 2)
    let radius = width * 0.135

    ctx.saveGState()
    ctx.translateBy(x: center.x, y: top)
    ctx.rotate(by: tilt * .pi / 180)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 60), blur: 140, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(rgb(0x050506).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Titanium-like rim.
    ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 3, dy: 3), cornerWidth: radius - 3, cornerHeight: radius - 3, transform: nil))
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.setLineWidth(5)
    ctx.strokePath()

    let screen = body.insetBy(dx: bezel, dy: bezel)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: radius - bezel, cornerHeight: radius - bezel, transform: nil))
    ctx.clip()
    drawImage(shot, in: screen)
    ctx.restoreGState()
    ctx.restoreGState()
}

func chip(_ c: Chip, panelX: CGFloat) {
    let icon = NSImage(systemSymbolName: c.symbol, accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: 64, weight: .semibold))!
    let title = NSAttributedString(string: c.title, attributes: [.font: outfit(44, .bold), .foregroundColor: rgb(0x0B0B0C)])
    let detail = NSAttributedString(string: c.detail, attributes: [.font: outfit(32, .medium), .foregroundColor: rgb(0x56565D)])
    let textW = max(title.size().width, detail.size().width)
    let size = CGSize(width: 40 + 104 + 28 + textW + 48, height: 184)
    let rect = CGRect(x: panelX + c.x * W, y: c.y, width: size.width, height: size.height)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 34), blur: 70, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 56, cornerHeight: 56, transform: nil))
    ctx.setFillColor(paper.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    let disc = CGRect(x: rect.minX + 40, y: rect.midY - 52, width: 104, height: 104)
    ctx.setFillColor(c.tint.withAlphaComponent(0.16).cgColor)
    ctx.fillEllipse(in: disc)
    let tinted = NSImage(size: icon.size, flipped: false) { r in
        icon.draw(in: r)
        c.tint.set()
        r.fill(using: .sourceAtop)
        return true
    }
    let iconSize = CGSize(width: 60, height: 60 * icon.size.height / icon.size.width)
    tinted.draw(in: CGRect(x: disc.midX - iconSize.width / 2, y: disc.midY - iconSize.height / 2,
                           width: iconSize.width, height: iconSize.height))

    title.draw(at: CGPoint(x: disc.maxX + 28, y: rect.minY + 36))
    detail.draw(at: CGPoint(x: disc.maxX + 28, y: rect.minY + 98))
}

/// Pesolita's own widgets, cut from `raw/widget-home.png` (a 9:41 Home Screen with the store
/// wallet): the small one and the large one.
let widgetHome: CGImage = loadImage("widget-home")
let smallWidget = widgetHome.cropping(to: CGRect(x: 96, y: 287, width: 520, height: 525))!
let largeWidget = widgetHome.cropping(to: CGRect(x: 96, y: 934, width: 1128, height: 1182))!

func floatWidget(_ image: CGImage, center: CGPoint, scale: CGFloat, radius: CGFloat, tilt: CGFloat) {
    let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    let r = radius * scale
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: tilt * .pi / 180)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 44), blur: 110, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.setFillColor(rgb(0x161618).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.clip()
    drawImage(image, in: rect)
    ctx.restoreGState()
    ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerWidth: r - 2, cornerHeight: r - 2, transform: nil))
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
    ctx.setLineWidth(4)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Background: one continuous piece

ctx.setFillColor(ink.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: PW, height: H))

// Glows placed on panel edges as often as inside them, so neighbours share light.
let glows: [(NSColor, CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (gold, 0.30, 0.10, 1100, 0.30), (blue, 1.05, 0.55, 1300, 0.34), (violet, 2.0, 0.20, 1100, 0.26),
    (blue, 2.9, 0.72, 1200, 0.28), (green, 4.0, 0.30, 1100, 0.22), (gold, 4.95, 0.62, 1300, 0.30),
    (blue, 6.0, 0.18, 1100, 0.30), (violet, 7.0, 0.66, 1200, 0.26), (gold, 8.0, 0.25, 1200, 0.26),
    (blue, 8.9, 0.70, 1100, 0.30),
]
for (color, px, py, r, a) in glows { glow(color, at: CGPoint(x: px * W, y: py * H), radius: r, alpha: a) }

// The gold ribbon: one wave across the whole gallery, behind every phone.
func ribbon(offset: CGFloat, amplitude: CGFloat, width: CGFloat, colors: [NSColor]) {
    let path = CGMutablePath()
    let steps = Int(N * 40)
    for i in 0...steps {
        let x = CGFloat(i) / CGFloat(steps) * PW
        let y = H * 0.66 + offset + sin(x / W * .pi * 0.92 + 0.6) * amplitude + sin(x / W * 2.1) * amplitude * 0.25
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    ctx.saveGState()
    ctx.addPath(path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: colors.map(\.cgColor) as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: PW, y: 0), options: [])
    ctx.restoreGState()
}
ribbon(offset: 0, amplitude: 380, width: 150,
       colors: [gold, rgb(0xF0A91D), gold, rgb(0xFFD95A), rgb(0xF0A91D), gold])
ribbon(offset: 120, amplitude: 300, width: 26,
       colors: [blue.withAlphaComponent(0.8), violet.withAlphaComponent(0.8), blue.withAlphaComponent(0.8)])

// Faint peso marks, like the app's Pro sheet.
for i in 0..<Int(N * 3) {
    let x = CGFloat(i) * W / 3 + (i % 2 == 0 ? 120 : 260)
    let y = CGFloat([380, 2500, 1200][i % 3])
    NSAttributedString(string: "₱", attributes: [.font: outfit(150, .bold),
                                                   .foregroundColor: NSColor.white.withAlphaComponent(0.035)])
        .draw(at: CGPoint(x: x, y: y))
}

// MARK: - Panels

for (index, panel) in panels.enumerated() {
    let px = CGFloat(index) * W
    let margin: CGFloat = 96

    // Eyebrow pill.
    let eyebrow = NSAttributedString(string: panel.eyebrow, attributes: [
        .font: outfit(34, .bold), .foregroundColor: gold, .kern: 5])
    let eyebrowSize = eyebrow.size()
    let pill = CGRect(x: px + (W - eyebrowSize.width - 64) / 2, y: 190, width: eyebrowSize.width + 64, height: 76)
    ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 38, cornerHeight: 38, transform: nil))
    ctx.setFillColor(gold.withAlphaComponent(0.14).cgColor)
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: pill.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 37, cornerHeight: 37, transform: nil))
    ctx.setStrokeColor(gold.withAlphaComponent(0.42).cgColor)
    ctx.setLineWidth(3)
    ctx.strokePath()
    eyebrow.draw(at: CGPoint(x: pill.minX + 32, y: pill.midY - eyebrowSize.height / 2))

    // Headline, gold where marked.
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    centered.lineHeightMultiple = 0.94
    let head = NSMutableAttributedString()
    var inGold = false
    // Simple scanner for {…}.
    var buffer = ""
    func flush() {
        guard !buffer.isEmpty else { return }
        head.append(NSAttributedString(string: buffer, attributes: [
            .font: outfit(118, .heavy), .foregroundColor: inGold ? gold : NSColor.white,
            .kern: -118 * 0.035, .paragraphStyle: centered]))
        buffer = ""
    }
    for ch in panel.headline {
        if ch == "{" { flush(); inGold = true } else if ch == "}" { flush(); inGold = false } else { buffer.append(ch) }
    }
    flush()
    var y = pill.maxY + 46
    y += text(head, x: px + margin, y: y, width: W - margin * 2)

    let bodyStyle = NSMutableParagraphStyle()
    bodyStyle.alignment = .center
    bodyStyle.lineHeightMultiple = 1.18
    let body = NSAttributedString(string: panel.body, attributes: [
        .font: outfit(44, .regular), .foregroundColor: NSColor.white.withAlphaComponent(0.72), .paragraphStyle: bodyStyle])
    y += 30
    y += text(body, x: px + margin + 40, y: y, width: W - (margin + 40) * 2)

    let deviceTop = y + 90
    if panel.shots.count == 2 {
        phone(loadImage(panel.shots[0]), center: CGPoint(x: px + W * 0.34, y: 0), width: 820, top: deviceTop + 120, tilt: -6)
        phone(loadImage(panel.shots[1]), center: CGPoint(x: px + W * 0.66, y: 0), width: 820, top: deviceTop + 40, tilt: 6)
    } else if panel.widget {
        // The real widgets, lifted off a 9:41 Home Screen capture of the store wallet.
        floatWidget(smallWidget, center: CGPoint(x: px + W * 0.29, y: deviceTop + 250), scale: 0.9, radius: 70, tilt: -6)
        floatWidget(largeWidget, center: CGPoint(x: px + W / 2, y: deviceTop + 580 + CGFloat(largeWidget.height) * 0.97 / 2),
                    scale: 0.97, radius: 72, tilt: 0)
    } else {
        phone(loadImage(panel.shots[0]), center: CGPoint(x: px + W / 2, y: 0), width: 1010, top: deviceTop, tilt: panel.tilt)
    }

    if index == 0 {
        floatWidget(smallWidget, center: CGPoint(x: px + W - 250, y: 2330), scale: 0.72, radius: 70, tilt: 7)
    }
    for c in panel.chips { chip(c, panelX: px) }
}

// MARK: - Slice and save

let panorama = ctx.makeImage()!
let outRoot = root.appendingPathComponent("AppStore-v2")
for (name, size) in [("iphone-6.9", CGSize(width: 1320, height: 2868)), ("iphone-6.5", CGSize(width: 1284, height: 2778))] {
    let dir = outRoot.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: dir)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for index in 0..<panels.count {
        let slice = panorama.cropping(to: CGRect(x: CGFloat(index) * W, y: 0, width: W, height: H))!
        // 6.5" is a touch wider for its height: scale to width, trim the difference evenly.
        let scaledH = (H * size.width / W).rounded()
        let out = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                            bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        out.interpolationQuality = .high
        out.draw(slice, in: CGRect(x: 0, y: (size.height - scaledH) / 2, width: size.width, height: scaledH))
        let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
        let url = dir.appendingPathComponent(String(format: "%02d.png", index + 1))
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
    print("\(name): \(panels.count) panels at \(Int(size.width))×\(Int(size.height))")
}
let preview = NSBitmapImageRep(cgImage: panorama)
try preview.representation(using: .jpeg, properties: [.compressionFactor: 0.8])!
    .write(to: outRoot.appendingPathComponent("panorama-preview.jpg"))
