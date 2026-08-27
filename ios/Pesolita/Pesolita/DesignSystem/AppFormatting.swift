import SwiftUI
import CoreText

enum AppFont {
    static func registerBundledFont() {
        let url = Bundle.main.url(forResource: "Outfit-Variable", withExtension: "ttf")
            ?? Bundle.main.resourceURL?.appendingPathComponent("Fonts/Outfit-Variable.ttf")
        if let url { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    }

    static func outfit(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Outfit", size: size, relativeTo: style).weight(weight)
    }
}

extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let red, green, blue, alpha: Double
        switch raw.count {
        case 8:
            red = Double((value >> 24) & 0xff) / 255
            green = Double((value >> 16) & 0xff) / 255
            blue = Double((value >> 8) & 0xff) / 255
            alpha = Double(value & 0xff) / 255
        default:
            red = Double((value >> 16) & 0xff) / 255
            green = Double((value >> 8) & 0xff) / 255
            blue = Double(value & 0xff) / 255
            alpha = 1
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum MoneyFormat {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_PH")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func amount(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: abs(value))) ?? "0.00"
    }

    static func balance(_ value: Double, privateMode: Bool = false) -> String {
        guard !privateMode else { return "•••••" }
        return "\(value < 0 ? "−" : "")₱\(amount(value))"
    }

    /// Groups a partially-typed amount for display without disturbing what is still being
    /// typed. `amount(_:)` cannot do this: it parses to a Double, so a trailing "." or a
    /// half-entered decimal ("12.") would be swallowed and the field would fight the user
    /// mid-keystroke. Digits before the separator are grouped; everything after is passed
    /// through untouched, capped at two places.
    static func grouped(draft: String) -> String {
        guard !draft.isEmpty else { return "" }
        let parts = draft.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole = String(parts[0]).filter(\.isNumber)
        let grouped = groupDigits(whole)
        guard draft.contains(".") else { return grouped }
        let decimals = parts.count > 1 ? String(parts[1]).filter(\.isNumber).prefix(2) : ""
        return "\(grouped.isEmpty ? "0" : grouped).\(decimals)"
    }

    /// Removes grouping so a formatted field can be parsed back into a number.
    static func ungrouped(_ text: String) -> String {
        text.filter { $0.isNumber || $0 == "." }
    }

    private static func groupDigits(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var out = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset > 0, offset % 3 == 0 { out.append(",") }
            out.append(character)
        }
        return String(out.reversed())
    }
}

extension RGBSample {
    var relativeLuminance: Double {
        func channel(_ byte: Int) -> Double {
            let value = Double(byte) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }
}

struct CardTheme {
    var foreground: Color
    var dimmed: Color
    var useDarkText: Bool

    init(art: CardArt) {
        let mode = art.photo?.textMode ?? .auto
        let useDark: Bool
        switch mode {
        case .dark: useDark = true
        case .light: useDark = false
        case .auto:
            useDark = art.photo.map { $0.sample.relativeLuminance > 0.43 }
                ?? (Self.hexLuminance(art.c1) > 0.43)
        }
        useDarkText = useDark
        foreground = useDark ? Tokens.ink : .white
        dimmed = useDark ? Tokens.ink.opacity(0.55) : .white.opacity(0.62)
    }

    private static func hexLuminance(_ hex: String) -> Double {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard raw.count >= 6, let value = UInt64(raw.prefix(6), radix: 16) else { return 0 }
        return RGBSample(
            red: Int((value >> 16) & 0xff),
            green: Int((value >> 8) & 0xff),
            blue: Int(value & 0xff)
        ).relativeLuminance
    }
}
