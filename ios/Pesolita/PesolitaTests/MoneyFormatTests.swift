import Foundation
import Testing
@testable import Pesolita

@Suite
struct MoneyFormatTests {
    @Test func groupsThousandsAndAbove() {
        #expect(MoneyFormat.grouped(draft: "1000") == "1,000")
        #expect(MoneyFormat.grouped(draft: "15596") == "15,596")
        #expect(MoneyFormat.grouped(draft: "109404") == "109,404")
        #expect(MoneyFormat.grouped(draft: "1234567") == "1,234,567")
    }

    @Test func leavesShortNumbersAlone() {
        #expect(MoneyFormat.grouped(draft: "") == "")
        #expect(MoneyFormat.grouped(draft: "7") == "7")
        #expect(MoneyFormat.grouped(draft: "999") == "999")
    }

    /// The field must not fight a half-typed decimal: a trailing separator has to survive
    /// the round trip or the user can never reach the centavos.
    @Test func survivesPartiallyTypedDecimals() {
        #expect(MoneyFormat.grouped(draft: "1000.") == "1,000.")
        #expect(MoneyFormat.grouped(draft: "1000.5") == "1,000.5")
        #expect(MoneyFormat.grouped(draft: "15596.00") == "15,596.00")
        #expect(MoneyFormat.grouped(draft: ".5") == "0.5")
    }

    @Test func capsCentavosAtTwoPlaces() {
        #expect(MoneyFormat.grouped(draft: "12.3456") == "12.34")
    }

    @Test func ungroupedRoundTripsBackToAParsableNumber() {
        let typed = MoneyFormat.grouped(draft: "18761.60")
        #expect(typed == "18,761.60")
        #expect(MoneyFormat.ungrouped(typed) == "18761.60")
        #expect(Double(MoneyFormat.ungrouped(typed)) == 18761.60)
    }

    /// Grouping is display-only, so anything the user pastes with separators already in it
    /// still has to reduce to digits the store can parse.
    @Test func ungroupedStripsAnythingThatIsNotANumber() {
        #expect(MoneyFormat.ungrouped("₱1,234.50") == "1234.50")
        #expect(MoneyFormat.ungrouped("−₱15,596.00") == "15596.00")
    }
}
