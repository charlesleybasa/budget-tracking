import CoreGraphics
import Testing
@testable import Pesolita

/// The window sizes that decide Pesolita's layout, pinned to the devices they came from.
@Suite
struct LayoutMetricsTests {
    @Test func todaysIPhonesKeepTheirLayout() {
        for size in [CGSize(width: 402, height: 874), CGSize(width: 440, height: 956), CGSize(width: 390, height: 844)] {
            let layout = LayoutMetrics.resolve(size)
            #expect(layout.layoutClass == .compact)
            #expect(layout.cardSize == CGSize(width: 320, height: 196))
        }
    }

    @Test func duoFoldedAndSmallPhonesAreShort() {
        #expect(LayoutMetrics.resolve(CGSize(width: 466, height: 678)).layoutClass == .compactShort)
        #expect(LayoutMetrics.resolve(CGSize(width: 375, height: 667)).layoutClass == .compactShort)
    }

    @Test func duoUnfoldedIsExpandedWithTabBarInPortraitAndRailInLandscape() {
        let portrait = LayoutMetrics.resolve(CGSize(width: 669, height: 951))
        #expect(portrait.isExpanded)
        #expect(!portrait.usesRail)
        let landscape = LayoutMetrics.resolve(CGSize(width: 951, height: 669))
        #expect(landscape.isExpanded)
        #expect(landscape.usesRail)
        #expect(landscape.detailInPane)
    }

    @Test func cardsKeepTheirProportions() {
        for size in [CGSize(width: 466, height: 678), CGSize(width: 669, height: 951), CGSize(width: 951, height: 669)] {
            let card = LayoutMetrics.resolve(size).cardSize
            #expect(abs(card.width / card.height - 320.0 / 196.0) < 0.02)
        }
    }
}
