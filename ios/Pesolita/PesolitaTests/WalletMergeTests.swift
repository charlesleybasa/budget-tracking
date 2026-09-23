import Foundation
import Testing
@testable import Pesolita

@Suite
struct WalletMergeTests {
    private func card(_ id: String, _ nick: String, bal: Double = 100) -> Card {
        Card(id: id, kind: .debit, nick: nick, last4: "", exp: "—", bal: bal, limit: 0, art: .cash, frozen: false)
    }

    private func tx(_ id: String, card: String, at: Double = 1, split: Split? = nil) -> Transaction {
        Transaction(id: id, cardId: card, merchant: "Shop", cat: .food, amount: -600, at: at, note: "", split: split)
    }

    @Test func combiningKeepsEverythingFromBothSides() {
        var local = WalletSnapshot(); local.cards = [card("new", "Cash")]; local.tx = [tx("t-new", card: "new")]
        var cloud = WalletSnapshot(); cloud.cards = [card("old", "BDO")]; cloud.tx = [tx("t-old", card: "old")]
        let merged = WalletMerge.merge(local: local, cloud: cloud, localIsNewer: true)
        #expect(Set(merged.cards.map(\.id)) == ["new", "old"])
        #expect(Set(merged.tx.map(\.id)) == ["t-new", "t-old"])
    }

    /// The reason merging is safe: a shared entry appears once, never twice.
    @Test func sharedEntriesAreNeverDoubled() {
        var local = WalletSnapshot(); local.cards = [card("a", "GCash")]; local.tx = [tx("t1", card: "a")]
        let merged = WalletMerge.merge(local: local, cloud: local, localIsNewer: true)
        #expect(merged.cards.count == 1)
        #expect(merged.tx.count == 1)
    }

    @Test func newerSideWinsForASharedEntry() {
        var local = WalletSnapshot(); local.cards = [card("a", "GCash", bal: 500)]
        var cloud = WalletSnapshot(); cloud.cards = [card("a", "GCash", bal: 900)]
        #expect(WalletMerge.merge(local: local, cloud: cloud, localIsNewer: true).cards[0].bal == 500)
        #expect(WalletMerge.merge(local: local, cloud: cloud, localIsNewer: false).cards[0].bal == 900)
    }

    @Test func splitPartsTravelWithTheirTransaction() {
        let split = Split(mode: .even, mine: 300, parts: [SplitPart(personId: "p", name: "Migo", amount: 300, settledAt: 5)])
        var cloud = WalletSnapshot(); cloud.cards = [card("a", "GCash")]; cloud.tx = [tx("t", card: "a", split: split)]
        cloud.people = [Person(id: "p", name: "Migo", color: "#1d6ff2")]
        let merged = WalletMerge.merge(local: .empty, cloud: cloud, localIsNewer: false)
        #expect(merged.tx.first?.split?.parts.first?.settledAt == 5)
        #expect(merged.people.map(\.id) == ["p"])
    }

    @Test func thisPhonesPreferencesAreKept() {
        var local = WalletSnapshot(); local.appTheme = .dark; local.userName = "Rli"
        var cloud = WalletSnapshot(); cloud.appTheme = .light; cloud.userName = "Old"
        let merged = WalletMerge.merge(local: local, cloud: cloud, localIsNewer: false)
        #expect(merged.appTheme == .dark)
        #expect(merged.userName == "Rli")
    }

    /// The case ids cannot catch — the same real card typed in twice — is surfaced up front.
    @Test func previewFlagsTheSameCardTypedTwice() {
        var local = WalletSnapshot(); local.cards = [card("n1", "GCash"), card("n2", "Wallet cash")]
        var cloud = WalletSnapshot(); cloud.cards = [card("o1", "gcash "), card("o2", "BDO")]
        cloud.tx = [tx("t", card: "o1")]
        let preview = MergePreview(local: local, cloud: cloud)
        #expect(preview.sameNamedCards == ["gcash "])
        #expect(Set(preview.cardsFromBackup) == ["gcash ", "BDO"])
        #expect(preview.transactionsFromBackup == 1)
    }
}
