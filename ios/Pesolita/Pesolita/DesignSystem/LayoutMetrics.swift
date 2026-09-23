import SwiftUI

/// How much room the window gives Pesolita.
///
/// Decided from the window's own size, never the device model: the iPhone Duo is short and wide
/// when folded (466 × 678 pt), close to an iPad mini when unfolded (669 × 951 pt), and windows
/// can be resized in between. Size classes alone can't tell those apart — an iPhone can report a
/// compact width even at 669 pt — so the numbers screens need live here instead.
enum LayoutClass: Equatable, Sendable {
    /// Short windows: iPhone Duo folded, iPhone SE, short resizable windows. Same content, tighter.
    case compactShort
    /// Today's iPhones. Every number here matches the layout before the Duo.
    case compact
    /// iPhone Duo unfolded, and any window at least 600 pt wide: two panes, not a stretched phone.
    case expanded
}

struct LayoutMetrics: Equatable, Sendable {
    var layoutClass: LayoutClass
    var size: CGSize

    var isExpanded: Bool { layoutClass == .expanded }
    var isShort: Bool { layoutClass == .compactShort }

    /// A side rail next to two panes needs landscape-unfolded width. In portrait unfolded the rail
    /// would leave the right pane too narrow for activity rows, so the tab bar stays.
    var usesRail: Bool { isExpanded && size.width >= 860 }
    /// Card detail opens beside Home instead of over it — only where that pane can hold a card.
    var detailInPane: Bool { usesRail }

    /// Home's left pane: the cards, Spend / Top up and Safe to spend.
    var homeLeadingPaneWidth: CGFloat {
        guard isExpanded else { return size.width }
        // Unfolded, the Duo keeps a sensor strip along one edge (about 100 pt), so the panes
        // share less than the full width: the left pane takes what a card needs, no more.
        // Portrait unfolded splits 669 pt: the left pane gets a card's width plus margins, the
        // right keeps enough for the Out with friends row (about 264 pt) without overflowing.
        return usesRail ? 400 : min(360, (size.width * 0.52).rounded())
    }

    /// A wallet card, always at the card's own 320 × 196 proportions.
    var cardSize: CGSize {
        let width: CGFloat = switch layoutClass {
        case .compactShort: 300
        case .compact: Tokens.cardW
        case .expanded: min(360, homeLeadingPaneWidth - gutter * 2)
        }
        return CGSize(width: width, height: (width * Tokens.cardH / Tokens.cardW).rounded())
    }

    /// Side margin of a screen's content.
    var gutter: CGFloat { isExpanded ? 22 : 20 }
    /// Vertical rhythm between sections; short windows give up a quarter of it.
    var sectionGap: CGFloat { isShort ? 16 : 22 }
    /// Money keypad keys: 48 pt normally, still a comfortable 44 pt target when short.
    var keypadKeyHeight: CGFloat { isShort ? 44 : 48 }
    /// Mascot sprites and hero art on short windows.
    var spriteScale: CGFloat { isShort ? 0.78 : 1 }

    /// Longest line a scrolling column should run to on a wide window.
    static let readableWidth: CGFloat = 600
    /// Keypads, slide tracks and full-width buttons keep phone proportions inside wide panes.
    static let controlMaxWidth: CGFloat = 460
    /// Sheets on a wide window are cards of this width rather than full-width phone sheets.
    static let sheetWidth: CGFloat = 560

    static func resolve(_ size: CGSize) -> LayoutMetrics {
        let layoutClass: LayoutClass
        if size.width >= 600 { layoutClass = .expanded }
        else if size.height > 0, size.height < 760 { layoutClass = .compactShort }
        else { layoutClass = .compact }
        return LayoutMetrics(layoutClass: layoutClass, size: size)
    }

    /// A 402 × 874 pt iPhone — used until the real window has been measured, and in previews.
    static let standard = resolve(CGSize(width: 402, height: 874))
}

extension EnvironmentValues {
    @Entry var layout: LayoutMetrics = .standard
}

extension View {
    /// Keeps a column of text or controls at a readable width on wide windows, centred.
    func readableWidth(_ width: CGFloat = LayoutMetrics.readableWidth) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}
