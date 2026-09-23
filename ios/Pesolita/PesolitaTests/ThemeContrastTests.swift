import SwiftUI
import Testing
import UIKit
@testable import Pesolita

/// Holds every colour pairing the app actually uses to WCAG contrast, in both appearances.
///
/// The first theming pass shipped white text on a yellow button (1.5:1), secondary copy at
/// 2.8:1 and dark surfaces one RGB unit apart. None of that is visible in a code review — it
/// only shows up on a screen, in one mode. These tests make it a build failure instead.
@Suite
struct ThemeContrastTests {
    private enum Mode: CaseIterable {
        case light, dark
        var trait: UITraitCollection {
            UITraitCollection(userInterfaceStyle: self == .light ? .light : .dark)
        }
    }

    private static func luminance(_ color: Color, _ mode: Mode) -> Double {
        let resolved = UIColor(color).resolvedColor(with: mode.trait)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private static func contrast(_ a: Color, _ b: Color, _ mode: Mode) -> Double {
        let la = luminance(a, mode), lb = luminance(b, mode)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Every surface text can land on.
    private static let surfaces: [(String, Color)] = [
        ("bgBase", Tokens.bgBase), ("fill", Tokens.fill),
        ("fillRaised", Tokens.fillRaised), ("fillStrong", Tokens.fillStrong),
        ("surfaceOverlay", Tokens.surfaceOverlay),
    ]

    private func expectOnEverySurface(_ name: String, _ color: Color, atLeast minimum: Double) {
        for mode in Mode.allCases {
            for (surface, ground) in Self.surfaces {
                let ratio = Self.contrast(color, ground, mode)
                #expect(ratio >= minimum, "\(name) on \(surface) in \(mode): \(ratio) < \(minimum)")
            }
        }
    }

    @Test func primaryAndSecondaryTextReadOnEverySurface() {
        expectOnEverySurface("textPrimary", Tokens.textPrimary, atLeast: 4.5)
        expectOnEverySurface("textSecondary", Tokens.textSecondary, atLeast: 4.5)
        expectOnEverySurface("textCaption", Tokens.textCaption, atLeast: 4.5)
    }

    @Test func tertiaryTextClearsTheNonTextMinimum() {
        expectOnEverySurface("textTertiary", Tokens.textTertiary, atLeast: 3.0)
    }

    @Test func brandColouredWordsReadOnEverySurface() {
        expectOnEverySurface("link", Tokens.link, atLeast: 4.5)
        expectOnEverySurface("accentText", Tokens.accentText, atLeast: 4.5)
        expectOnEverySurface("positive", Tokens.positive, atLeast: 4.5)
        expectOnEverySurface("negative", Tokens.negative, atLeast: 4.5)
        expectOnEverySurface("violetText", Tokens.violetText, atLeast: 4.5)
    }

    /// The regression that started this: content on a fixed fill must itself be fixed.
    @Test func contentOnFixedFillsIsIdenticalAndLegibleInBothModes() {
        for mode in Mode.allCases {
            #expect(Self.contrast(Tokens.onAccent, Tokens.accent, mode) >= 4.5, "onAccent on yellow in \(mode)")
            #expect(Self.contrast(Tokens.onBrand, Tokens.blue, mode) >= 4.5, "onBrand on blue in \(mode)")
            #expect(Self.contrast(Tokens.onBrand, Tokens.greenDeep, mode) >= 4.5, "onBrand on deep green in \(mode)")
            // Brand green and red only ever carry icons or large figures under white.
            #expect(Self.contrast(Tokens.onBrand, Tokens.green, mode) >= 3.0, "onBrand on green in \(mode)")
            #expect(Self.contrast(Tokens.onBrand, Tokens.red, mode) >= 3.0, "onBrand on red in \(mode)")
        }
        #expect(Self.luminance(Tokens.onAccent, .light) == Self.luminance(Tokens.onAccent, .dark))
        #expect(Self.luminance(Tokens.onBrand, .light) == Self.luminance(Tokens.onBrand, .dark))
    }

    /// Avatars sit on a palette that includes yellow, so the initial is picked by contrast.
    @Test func avatarInitialsReadOnEveryPersonColour() {
        for hex in SplitMath.personColors {
            let ratio = Self.contrast(Tokens.on(hex: hex), Color(hex: hex), .light)
            #expect(ratio >= 3.0, "initial on \(hex): \(ratio)")
        }
    }

    /// Dark layers must be far enough apart to read as layers, not as one flat black.
    @Test func darkSurfacesHavePerceptibleElevation() {
        // Guard the harness itself: if trait resolution silently fell back to light, every
        // dark-mode assertion in this suite would be checking the wrong colours.
        #expect(Self.luminance(Tokens.bgBase, .dark) < 0.01)
        #expect(Self.luminance(Tokens.bgBase, .light) > 0.99)

        let ladder: [(String, Color)] = [
            ("bgBase", Tokens.bgBase), ("fill", Tokens.fill),
            ("fillRaised", Tokens.fillRaised), ("fillStrong", Tokens.fillStrong),
        ]
        for (lower, upper) in zip(ladder, ladder.dropFirst()) {
            let ratio = Self.contrast(lower.1, upper.1, .dark)
            #expect(ratio >= 1.08, "\(lower.0) → \(upper.0) in dark: \(ratio)")
        }
    }

    /// The legacy names were the inverted scale; they must now agree with their roles.
    @Test func legacyNamesResolveByIntentNotByInversion() {
        for mode in Mode.allCases {
            #expect(Self.luminance(Tokens.sand1, mode) == Self.luminance(Tokens.fill, mode))
            #expect(Self.luminance(Tokens.sand4, mode) == Self.luminance(Tokens.fillStrong, mode))
            #expect(Self.luminance(Tokens.line4, mode) == Self.luminance(Tokens.hairlineStrong, mode))
            #expect(Self.luminance(Tokens.muted1, mode) == Self.luminance(Tokens.textSecondary, mode))
        }
        // In light mode the quiet fill must be light — it resolved near-black before.
        #expect(Self.luminance(Tokens.sand1, .light) > 0.8)
    }
}
