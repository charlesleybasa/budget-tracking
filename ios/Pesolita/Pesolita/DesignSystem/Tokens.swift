import SwiftUI

private func dynamic(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

private func rgb(_ hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

/// Pesolita's colour system, for Light and Dark.
///
/// Colours are named by **role**, not by what they look like. The first theming pass inverted
/// every value ("dark is the original, light is its negative"), which broke in three ways: text
/// that flipped to white while sitting on a yellow fill that did not flip (1.5:1); a sand scale
/// that turned near-black in light mode; and dark surfaces 1–2 RGB units apart, so nothing had
/// depth. Roles fix all three at the source, and `ThemeContrastTests` holds every pairing to
/// WCAG in both modes so it cannot quietly regress.
public enum Tokens {
    // MARK: - Surfaces
    //
    // Dark steps sit roughly 1.1–1.15:1 apart so a sheet, the card on it and the chip on that
    // card each read as their own layer. Light keeps the original white-and-sand hierarchy.

    /// The page itself.
    public static let bgBase = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x0B0B0D))
    /// A quiet fill one step off the page: chips, fields, tiles.
    public static let fill = dynamic(light: rgb(0xF5F4F0), dark: rgb(0x1B1B20))
    /// One step further: selected pills, secondary tiles.
    public static let fillRaised = dynamic(light: rgb(0xF2F1EC), dark: rgb(0x24242B))
    /// Pressed and disabled fills, progress tracks, grabbers.
    public static let fillStrong = dynamic(light: rgb(0xE6E4DE), dark: rgb(0x2E2E36))
    /// A floating layer — tab bar, popovers — that needs to lift off whatever scrolls beneath.
    public static let surfaceOverlay = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x1E1E24))

    // MARK: - Text

    public static let textPrimary = dynamic(light: rgb(0x0B0B0C), dark: rgb(0xF5F4F0))
    /// Secondary copy. At least 4.5:1 on every surface above, in both modes.
    public static let textSecondary = dynamic(light: rgb(0x56565D), dark: rgb(0xB3B3BB))
    /// Captions and metadata. Also at least 4.5:1.
    public static let textCaption = dynamic(light: rgb(0x64646B), dark: rgb(0x9A9AA3))
    /// Placeholders and faint icons. At least 3:1 — never for sentences.
    public static let textTertiary = dynamic(light: rgb(0x7C7C83), dark: rgb(0x7D7D86))
    /// Disabled content. Deliberately below 3:1 so it reads as unavailable.
    public static let textDisabled = dynamic(light: rgb(0xB4B4BB), dark: rgb(0x55555D))

    // MARK: - Content on fixed fills
    //
    // The brand fills do not change between modes, so neither may the content on them.

    /// For anything on yellow `accent`. Always ink — white on yellow is 1.5:1.
    public static let onAccent = Color(uiColor: rgb(0x0B0B0C))
    /// For anything on blue, green or red fills. Always white.
    public static let onBrand = Color(uiColor: rgb(0xFFFFFF))

    // MARK: - Brand colours used as text
    //
    // The fills are fixed, but brand-coloured *words* have to clear 4.5:1 on whichever page
    // they land on, so they get a darker light-mode variant and a lighter dark-mode one.

    public static let link = dynamic(light: rgb(0x1558CC), dark: rgb(0x6AA3FF))
    public static let accentText = dynamic(light: rgb(0x735400), dark: rgb(0xFFCA28))
    public static let positive = dynamic(light: rgb(0x07704D), dark: rgb(0x3CCB9A))
    public static let negative = dynamic(light: rgb(0xC0271E), dark: rgb(0xFF6B61))

    // MARK: - Tints
    //
    // Pale washes in light mode; deep, low-saturation versions in dark, so a tinted row never
    // becomes a bright block on a black page.

    public static let redTint = dynamic(light: rgb(0xFFF0EF), dark: rgb(0x2B1716))
    public static let greenTint = dynamic(light: rgb(0xE7F6EE), dark: rgb(0x0F2A21))
    public static let blueTint = dynamic(light: rgb(0xEEF4FF), dark: rgb(0x13203A))
    public static let accentTint = dynamic(light: rgb(0xFFF6D6), dark: rgb(0x2E2711))
    public static let violetTint = dynamic(light: rgb(0xF1EBFE), dark: rgb(0x211A33))

    // MARK: - Separators

    public static let hairline = dynamic(light: rgb(0xECEBE5), dark: rgb(0x2A2A31))
    public static let hairlineStrong = dynamic(light: rgb(0xE0DFD8), dark: rgb(0x383841))

    // MARK: - Fixed physical colours
    //
    // Card art, the Receive-money panel and anything drawn "on the plastic" — never themed.

    public static let absoluteInk = Color(uiColor: rgb(0x0B0B0C))
    public static let absolutePaper = Color(uiColor: rgb(0xFFFFFF))

    // MARK: - Brand fills (identical in both modes)

    public static let accent = Color(uiColor: rgb(0xFFCA28))
    public static let blue = Color(uiColor: rgb(0x1D6FF2))
    public static let blueDeep = Color(uiColor: rgb(0x0B3A8F))
    public static let red = Color(uiColor: rgb(0xF0483E))
    public static let redDeep = Color(uiColor: rgb(0xC62F26))
    public static let green = Color(uiColor: rgb(0x0B8F6A))
    /// For fills that carry white text: brand green is 4.1:1 under white, this is 5.1:1.
    public static let greenDeep = Color(uiColor: rgb(0x0A7D5D))
    public static let cream = Color(uiColor: rgb(0xF4EEDC))
    public static let pink = Color(uiColor: rgb(0xF9A8B4))

    // MARK: - Legacy names
    //
    // Kept so the ~300 existing call sites compile, and mapped by what each name was *used*
    // for — not by inverting its original value. `sand*`/`line*` previously resolved to
    // near-black in light mode; every surviving use (grabbers, hairlines, the disabled Log-it
    // button) wanted the light meaning, and now gets it in both modes.

    public static let background = bgBase
    public static let text = textPrimary
    public static let paper = textPrimary

    public static let dark1 = fill
    public static let dark2 = fillRaised
    public static let dark3 = fillRaised
    public static let darkHover = fillStrong

    public static let sand1 = fill
    public static let sand2 = fillRaised
    public static let sand3 = fillStrong
    public static let sand4 = fillStrong
    public static let sandHover = fillRaised

    public static let line1 = hairline
    public static let line2 = hairline
    public static let line3 = hairline
    public static let line4 = hairlineStrong

    /// `muted1` was always the strongest secondary colour and `muted5` the faintest; the first
    /// theming pass reversed that ordering in light mode.
    public static let muted1 = textSecondary
    public static let muted2 = textCaption
    public static let muted3 = textTertiary
    public static let muted4 = textDisabled
    public static let muted5 = textDisabled

    /// Ink or white — whichever reads better on a fixed colour such as a person's avatar.
    ///
    /// Avatar colours come from a palette that includes yellow, so neither a fixed white nor
    /// an adaptive text colour is right for every face: picked by contrast, not by mode.
    public static func on(hex: String) -> Color {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard raw.count >= 6, let value = UInt32(raw.prefix(6), radix: 16) else { return onBrand }
        func channel(_ shift: UInt32) -> Double {
            let c = Double((value >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        let againstWhite = 1.05 / (luminance + 0.05)
        let againstInk = (luminance + 0.05) / 0.0537
        return againstInk > againstWhite ? onAccent : onBrand
    }

    /// A category colour drawn as a small glyph on a pale tint. Yellow ("Shopping") is too
    /// light to read as an icon on a light wash, so light colours fall back to `accentText`.
    public static func glyph(hex: String) -> Color {
        on(hex: hex) == onAccent ? accentText : Color(hex: hex)
    }

    public static let violetText = dynamic(light: rgb(0x6D28D9), dark: rgb(0xB49BFF))

    public static let bluePale = blueTint
    public static let blueLine = dynamic(light: rgb(0xD7E5FF), dark: rgb(0x1F3357))
    public static let greenPale = greenTint

    // MARK: - Motion

    /// Durations come from the call site because CSS carries them on each declaration,
    /// not on the easing token.
    public static func easeOut(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1, duration: duration)
    }
    public static func easeSpring(_ duration: Double) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }

    /// Literal curves used outside the two named tokens.
    public static func dealCurve(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0.9, 0.22, 1, duration: duration)
    }

    public static func flipCurve(_ duration: Double) -> Animation {
        .timingCurve(0.22, 1, 0.28, 1, duration: duration)
    }

    // MARK: - Layout

    public static let appMaxW: CGFloat = 480
    public static let railW: CGFloat = 76
    public static let paneGap: CGFloat = 20
    public static let contentMax: CGFloat = 720

    // MARK: - Card geometry

    /// The art engine is authored against this box; every size scales off the width.
    public static let cardW: CGFloat = 320
    public static let cardH: CGFloat = 196
    public static let cardR: CGFloat = 22
    public static let deckStep: CGFloat = 334
    public static let deckOrigin: CGFloat = 22

    // MARK: - Card palettes

    public static let palettes: [(base: Color, accent: Color)] = [
        (Color(red: 1.0000, green: 0.7922, blue: 0.1569), Color(red: 0.0431, green: 0.0431, blue: 0.0471)),
        (Color(red: 0.1137, green: 0.4353, blue: 0.9490), Color(red: 0.9569, green: 0.9333, blue: 0.8627)),
        (Color(red: 0.9569, green: 0.9333, blue: 0.8627), Color(red: 0.9412, green: 0.2824, blue: 0.2431)),
        (Color(red: 0.9765, green: 0.6588, blue: 0.7059), Color(red: 0.9412, green: 0.2824, blue: 0.2431)),
        (Color(red: 0.0863, green: 0.0863, blue: 0.1020), Color(red: 1.0000, green: 0.7922, blue: 0.1569)),
        (Color(red: 0.0431, green: 0.5608, blue: 0.4157), Color(red: 0.9569, green: 0.9333, blue: 0.8627)),
    ]

    // MARK: - Category colors

    public static let categoryColors: [String: Color] = [
        "Food": Color(red: 0.9412, green: 0.2824, blue: 0.2431),
        "Transport": Color(red: 0.1137, green: 0.4353, blue: 0.9490),
        "Bills": Color(red: 0.4863, green: 0.2275, blue: 0.9294),
        "Groceries": Color(red: 0.0431, green: 0.5608, blue: 0.4157),
        "Shopping": Color(red: 1.0000, green: 0.7922, blue: 0.1569),
        "Load": Color(red: 0.9255, green: 0.2824, blue: 0.6000),
        "Health": Color(red: 0.0314, green: 0.5686, blue: 0.6980),
        "Fun": Color(red: 0.9765, green: 0.4510, blue: 0.0863),
    ]

    // MARK: - Legibility tuner tables

    /// Scrim ladder — alpha of the wash behind card text.
    public static let scrim: [String: Double] = [
        "off": 0,
        "soft": 0.32,
        "strong": 0.55,
        "veil": 0.5,
    ]

    /// Pattern amplitudes the tuner damps through, strongest first.
    public static let amplitudes: [Double] = [1, 0.8, 0.62, 0.48, 0.36, 0.26, 0.18, 0.12]

    /// Peak accent and white coverage each style's pattern can reach.
    public static let patternDuty: [String: (amax: Double, wmax: Double)] = [
        "grid": (0.95, 0.05),
        "planes": (0.85, 0.3),
        "metal": (0.9, 0.5),
        "glyph": (0.15, 0.14),
        "orbit": (0.55, 0.3),
        "foil": (0.95, 0.12),
        "irid": (0.9, 0.55),
        "crest": (0.85, 0.26),
        "blob": (0.92, 0.93),
        "wave": (0.9, 0.95),
        "arc": (0.95, 0.05),
        "mesh": (0.95, 0.32),
        "confetti": (0.9, 0.8),
    ]
}
