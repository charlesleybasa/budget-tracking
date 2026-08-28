import Foundation
import Testing
@testable import Pesolita

@Suite(.serialized)
@MainActor
struct WalletStoreTests {
    @Test func allTemplateIDsAreUniqueAndComplete() {
        #expect(CardTemplates.all.count == 70)
        #expect(Set(CardTemplates.all.map(\.id)).count == 70)
        #expect(Set(CardTemplates.all.map(\.category)) == Set(TemplateCategory.allCases))
    }

    @Test func onboardingCreatesTheChosenTemplateCard() {
        let store = WalletStore(repository: nil)
        store.onboarding.name = "Rli"
        store.selectKind(.debit)
        let template = CardTemplates.byID["banks/deep-blue-wave"]!
        store.selectTemplate(template)
        store.onboarding.balance = "2500"
        store.finishOnboarding()

        #expect(store.snapshot.onboarded)
        #expect(store.snapshot.cards.count == 1)
        #expect(store.snapshot.cards[0].nick == "Deep Blue Wave")
        #expect(store.snapshot.cards[0].bal == 2500)
        #expect(store.snapshot.cards[0].art.photo?.src == "template:banks/deep-blue-wave.webp")
    }

    @Test func spendingExactlyTheBalanceIsAllowed() {
        let store = WalletStore(snapshot: snapshot(balance: 100), repository: nil)
        store.openTransaction(.withdraw, cardID: "card")
        store.amountDraft = "100"
        store.noteDraft = "Lunch"
        store.saveTransaction()

        #expect(store.snapshot.cards[0].bal == 0)
        #expect(store.snapshot.tx.first?.amount == -100)
        #expect(store.success?.kind == .logged)
    }

    @Test func overspendingAndFrozenCardsAreRejected() {
        let store = WalletStore(snapshot: snapshot(balance: 100), repository: nil)
        store.openTransaction(.withdraw, cardID: "card")
        store.amountDraft = "100.01"
        store.saveTransaction()
        #expect(store.snapshot.cards[0].bal == 100)
        #expect(store.snapshot.tx.isEmpty)

        var frozen = snapshot(balance: 100)
        frozen.cards[0].frozen = true
        let frozenStore = WalletStore(snapshot: frozen, repository: nil)
        frozenStore.openTransaction(.withdraw, cardID: "card")
        frozenStore.amountDraft = "50"
        frozenStore.saveTransaction()
        #expect(frozenStore.snapshot.cards[0].bal == 100)
        #expect(frozenStore.snapshot.tx.isEmpty)
    }

    @Test func topUpAddsMoneyAndAPositiveTransaction() {
        let store = WalletStore(snapshot: snapshot(balance: 100), repository: nil)
        store.openTransaction(.deposit, cardID: "card")
        store.amountDraft = "25.50"
        store.saveTransaction()
        #expect(store.snapshot.cards[0].bal == 125.50)
        #expect(store.snapshot.tx.first?.amount == 25.50)
        #expect(store.success?.kind == .funded)
    }

    @Test func transferConservesTotalAndRecordsDestination() {
        var value = snapshot(balance: 1_000)
        value.cards.append(Card(
            id: "savings",
            kind: .savings,
            nick: "Savings",
            last4: "",
            exp: "—",
            bal: 250,
            limit: 0,
            art: .cash,
            frozen: false
        ))
        let store = WalletStore(snapshot: value, repository: nil)
        store.openTransfer(from: "card")
        store.transferToID = "savings"
        store.amountDraft = "175"
        store.performTransfer()

        #expect(store.totalBalance == 1_250)
        #expect(store.snapshot.cards.first { $0.id == "card" }?.bal == 825)
        #expect(store.snapshot.cards.first { $0.id == "savings" }?.bal == 425)
        #expect(store.snapshot.tx.first?.cardId == "savings")
        #expect(store.snapshot.tx.first?.amount == 175)
        #expect(store.success?.body.contains("₱175.00") == true)
    }

    @Test func changingBundledTemplateUpdatesTheFollowedName() {
        var value = snapshot(balance: 100)
        value.cards[0].nick = "Crimson Wave"
        value.cards[0].art = CardTemplates.byID["banks/crimson-wave"]!.art
        let store = WalletStore(snapshot: value, repository: nil)
        store.openEditor(cardID: "card")
        store.applyTemplate(CardTemplates.byID["banks/deep-blue-wave"]!)

        #expect(store.editor?.card.nick == "Deep Blue Wave")
        #expect(store.editor?.card.art.photo?.src == "template:banks/deep-blue-wave.webp")
    }

    @Test func deletingCardAlsoDeletesItsActivity() {
        var value = snapshot(balance: 100)
        value.tx = [Transaction(
            id: "tx",
            cardId: "card",
            merchant: "Lunch",
            cat: .food,
            amount: -25,
            at: Date().timeIntervalSince1970 * 1_000,
            note: ""
        )]
        let store = WalletStore(snapshot: value, repository: nil)
        store.openEditor(cardID: "card")
        store.deleteEditorCard()

        #expect(store.snapshot.cards.isEmpty)
        #expect(store.snapshot.tx.isEmpty)
        #expect(store.snapshot.activeId.isEmpty)
    }

    @Test func editingAndDeletingSpendKeepsBalanceCorrect() {
        var value = snapshot(balance: 900)
        value.tx = [Transaction(
            id: "tx",
            cardId: "card",
            merchant: "Lunch",
            cat: .food,
            amount: -100,
            at: Date().timeIntervalSince1970 * 1_000,
            note: "Lunch"
        )]
        let store = WalletStore(snapshot: value, repository: nil)
        store.openTransactionEditor("tx")
        store.transactionEditor?.amount = "125"
        store.saveTransactionEditor()
        #expect(store.snapshot.cards[0].bal == 875)
        #expect(store.snapshot.tx[0].amount == -125)

        store.deleteTransaction("tx")
        #expect(store.snapshot.cards[0].bal == 1_000)
        #expect(store.snapshot.tx.isEmpty)
    }

    @Test func searchMatchesDirectionCategoryAndNote() {
        let rows = [
            Transaction(id: "a", cardId: "card", merchant: "Jollibee", cat: .food, amount: -90, at: 2, note: "Lunch"),
            Transaction(id: "b", cardId: "card", merchant: "Salary", cat: .bills, amount: 1_000, at: 1, note: "Payday"),
        ]
        #expect(WalletMetrics.search(rows, query: "lunch", filter: .all).map(\.id) == ["a"])
        #expect(WalletMetrics.search(rows, query: "", filter: .moneyIn).map(\.id) == ["b"])
        #expect(WalletMetrics.search(rows, query: "", filter: .food).map(\.id) == ["a"])
    }

    @Test func restoringBackupReplacesWalletAndReturnsHome() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let media = MediaStore(directory: root)
        var backup = snapshot(balance: 2_500)
        backup.userName = "Restored"
        backup.haptics = false
        backup.sfx = false
        let data = try await BackupCodec.export(backup, media: media)

        let store = WalletStore(snapshot: snapshot(balance: 10), repository: nil, mediaStore: media)
        store.selectedTab = .settings
        store.path = [.detail("card")]
        let succeeded = await store.restoreBackup(data)

        #expect(succeeded)
        #expect(store.snapshot.userName == "Restored")
        #expect(store.snapshot.cards.first?.bal == 2_500)
        #expect(store.snapshot.haptics == false)
        #expect(store.snapshot.sfx == false)
        #expect(store.selectedTab == .home)
        #expect(store.path.isEmpty)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func widgetPayloadKeepsCardArtPrivacyAndRecentActivity() {
        var value = snapshot(balance: 1_200)
        value.privacy = true
        value.tx = [Transaction(
            id: "widget-tx",
            cardId: "card",
            merchant: "Coffee",
            cat: .food,
            amount: -145,
            at: 123_000,
            note: ""
        )]

        let payload = WidgetWalletPayload(snapshot: value, now: Date(timeIntervalSince1970: 1_000))

        #expect(payload.cards.count == 1)
        #expect(payload.cards[0].templatePath == "banks/navy-wave.webp")
        #expect(payload.cards[0].balance == 1_200)
        #expect(payload.transactions.first?.merchant == "Coffee")
        #expect(payload.privacyEnabled)
        #expect(payload.totalBalance == 1_200)
    }

    @Test func widgetDeepLinksOpenTheRequestedCardAndMoneyFlow() async {
        var value = snapshot(balance: 800)
        value.cards.append(Card(
            id: "cash",
            kind: .cash,
            nick: "Cash on Hand",
            last4: "",
            exp: "—",
            bal: 200,
            limit: 0,
            art: .cash,
            frozen: false
        ))
        let store = WalletStore(snapshot: value, repository: nil)
        await store.load()

        store.handleDeepLink(URL(string: "pesolita://spend?card=cash")!)
        #expect(store.sheet == .withdraw)
        #expect(store.sheetCardID == "cash")

        store.dismissSheet()
        store.handleDeepLink(URL(string: "pesolita://topup?card=card")!)
        #expect(store.sheet == .deposit)
        #expect(store.sheetCardID == "card")
        #expect(store.selectedTab == .home)
    }

    private func snapshot(balance: Double) -> WalletSnapshot {
        var snapshot = WalletSnapshot()
        snapshot.cards = [Card(
            id: "card",
            kind: .debit,
            nick: "Everyday",
            last4: "1234",
            exp: "12/30",
            bal: balance,
            limit: 0,
            art: CardTemplates.all[0].art,
            frozen: false
        )]
        snapshot.activeId = "card"
        snapshot.userName = "Rli"
        snapshot.onboarded = true
        return snapshot
    }
}
