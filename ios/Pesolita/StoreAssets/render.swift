import AppKit
import CoreText

// Renders App Store screenshots at Apple's exact 6.9" pixel size, in the app's own
// typeface. Sharp's SVG renderer silently falls back to a system font and the browser
// pane caps out well below store resolution, so the marketing copy is drawn with Core
// Text against the same Outfit file the app registers at launch.

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let build = root.appendingPathComponent("build")
let out = root.appendingPathComponent("AppStore/iphone-6.9")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let fontURL = build.appendingPathComponent("Outfit.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

func outfit(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont(name: "Outfit", size: size) ?? .systemFont(ofSize: size, weight: weight)
    let descriptor = base.fontDescriptor.addingAttributes([
        .traits: [NSFontDescriptor.TraitKey.weight: weight]
    ])
    return NSFont(descriptor: descriptor, size: size) ?? base
}

struct Panel {
    let file: String, headline: String, body: String, style: String
}

let panels: [Panel] = [
    .init(file: "07-home-with-activity",
          headline: "Every peso\ngets a home.",
          body: "A pocket for every card, wallet and stash of cash — with a running total you can trust.",
          style: "ink"),
    .init(file: "11-grouped-amount",
          headline: "It stops you\noverspending.",
          body: "Try to spend more than a card holds and Pesolita blocks it, then offers to spend what is actually there.",
          style: "amber"),
    .init(file: "02-template-picker",
          headline: "70 card designs.\nPick yours.",
          body: "Bank, e-wallet, credit, prepaid or plain cash — your wallet on screen looks like the one in your pocket.",
          style: "ink"),
    .init(file: "06-logged-success",
          headline: "Logged in\nfour seconds.",
          body: "A keypad built for money, not a form. Type the amount, tap once, done.",
          style: "blue"),
    .init(file: "01-onboarding-intro",
          headline: "No bank login.\nEver.",
          body: "Pesolita never connects to your bank. Every number you enter stays on this iPhone.",
          style: "ink"),
]

let W: CGFloat = 1320, H: CGFloat = 2868

func draw(_ panel: Panel, index: Int) throws {
    guard let shot = NSImage(contentsOf: build.appendingPathComponent("\(panel.file).png")),
          let shotRef = shot.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { throw NSError(domain: "missing \(panel.file)", code: 1) }

    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                              bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw NSError(domain: "context", code: 2) }

    // Background — flat ink, or a gradient for the two accent panels.
    switch panel.style {
    case "amber":
        let g = CGGradient(colorsSpace: space, colors: [
            CGColor(red: 1.0, green: 0.792, blue: 0.157, alpha: 1),
            CGColor(red: 0.941, green: 0.663, blue: 0.114, alpha: 1)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: H), end: CGPoint(x: W * 0.35, y: 0),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    case "blue":
        let g = CGGradient(colorsSpace: space, colors: [
            CGColor(red: 0.184, green: 0.486, blue: 0.965, alpha: 1),
            CGColor(red: 0.113, green: 0.435, blue: 0.949, alpha: 1)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: H), end: CGPoint(x: W * 0.35, y: 0),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    default:
        ctx.setFillColor(CGColor(red: 0.043, green: 0.043, blue: 0.047, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    }

    let dark = panel.style == "amber"
    let headColor = dark ? NSColor(red: 0.043, green: 0.043, blue: 0.047, alpha: 1) : .white
    let bodyColor = dark ? NSColor(red: 0.043, green: 0.043, blue: 0.047, alpha: 0.66)
                         : NSColor(white: 1, alpha: panel.style == "blue" ? 0.78 : 0.62)

    let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsctx

    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    centered.lineHeightMultiple = 0.98

    let head = NSAttributedString(string: panel.headline, attributes: [
        .font: outfit(104, .heavy), .foregroundColor: headColor,
        .kern: -104 * 0.045, .paragraphStyle: centered,
    ])
    let headHeight = head.boundingRect(with: CGSize(width: W - 192, height: .greatestFiniteMagnitude),
                                       options: .usesLineFragmentOrigin).height
    head.draw(with: CGRect(x: 96, y: H - 150 - headHeight, width: W - 192, height: headHeight),
              options: .usesLineFragmentOrigin)

    let bodyStyle = NSMutableParagraphStyle()
    bodyStyle.alignment = .center
    bodyStyle.lineHeightMultiple = 1.28
    let body = NSAttributedString(string: panel.body, attributes: [
        .font: outfit(40, .regular), .foregroundColor: bodyColor, .paragraphStyle: bodyStyle,
    ])
    let bodyHeight = body.boundingRect(with: CGSize(width: W - 260, height: .greatestFiniteMagnitude),
                                       options: .usesLineFragmentOrigin).height
    body.draw(with: CGRect(x: 130, y: H - 150 - headHeight - 34 - bodyHeight,
                           width: W - 260, height: bodyHeight), options: .usesLineFragmentOrigin)
    NSGraphicsContext.restoreGraphicsState()

    // Device shot, bled off the bottom edge so the panel reads as a continuing screen.
    let deviceW: CGFloat = 1044
    let deviceH = deviceW * (CGFloat(shotRef.height) / CGFloat(shotRef.width))
    let rect = CGRect(x: (W - deviceW) / 2, y: -deviceH * 0.055, width: deviceW, height: deviceH)
    let path = CGPath(roundedRect: rect, cornerWidth: 74, cornerHeight: 74, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -46), blur: 110,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
    ctx.addPath(path)
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.draw(shotRef, in: rect)
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.setLineWidth(12)
    ctx.strokePath()
    ctx.restoreGState()

    guard let image = ctx.makeImage() else { throw NSError(domain: "image", code: 3) }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "png", code: 4) }
    let url = out.appendingPathComponent(String(format: "%02d-%@.png", index + 1, panel.file))
    try data.write(to: url)
    print("\(url.lastPathComponent)  \(image.width)x\(image.height)")
}

for (index, panel) in panels.enumerated() { try draw(panel, index: index) }
