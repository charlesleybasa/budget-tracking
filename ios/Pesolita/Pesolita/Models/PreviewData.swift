import Foundation

extension WalletSnapshot {
    static var simulatorDemo: WalletSnapshot {
        let everyday = Card(
            id: "card_everyday",
            kind: .debit,
            nick: "BDO Debit",
            last4: "4821",
            exp: "12 / 30",
            bal: 8_425.50,
            limit: 15_000,
            art: CardTemplates.byID["banks/bdo-debit"]!.art,
            frozen: false,
            accountNumber: "0012 4821 7700"
        )
        let wallet = Card(
            id: "card_wallet",
            kind: .eWallet,
            nick: "GCash",
            last4: "1128",
            exp: "—",
            bal: 2_180,
            limit: 5_000,
            art: CardTemplates.byID["e-wallets/gcash-ewallet"]!.art,
            frozen: false,
            accountNumber: "0917 555 1128"
        )
        let cash = Card(
            id: "card_cash",
            kind: .cash,
            nick: "Cash on Hand",
            last4: "",
            exp: "—",
            bal: 760,
            limit: 3_000,
            art: .cash,
            frozen: false
        )
        let now = Date().timeIntervalSince1970 * 1_000
        var value = WalletSnapshot()
        value.cards = [everyday, wallet, cash]
        value.tx = [
            Transaction(id: "tx_1", cardId: everyday.id, merchant: "Jollibee", cat: .food, amount: -245, at: now - 3_600_000, note: "Lunch"),
            Transaction(id: "tx_2", cardId: wallet.id, merchant: "Grab", cat: .transport, amount: -189, at: now - 8_200_000, note: "Ride home"),
            Transaction(id: "tx_3", cardId: everyday.id, merchant: "Salary", cat: .bills, amount: 12_000, at: now - 86_400_000, note: "Payday"),
            Transaction(id: "tx_4", cardId: everyday.id, merchant: "Meralco", cat: .bills, amount: -1_870, at: now - 172_800_000, note: "Electric bill"),
            Transaction(id: "tx_5", cardId: cash.id, merchant: "Puregold", cat: .groceries, amount: -840, at: now - 259_200_000, note: "Weekly groceries"),
            Transaction(id: "tx_6", cardId: wallet.id, merchant: "Mobile load", cat: .load, amount: -99, at: now - 345_600_000, note: "Smart"),
        ]
        value.activeId = everyday.id
        value.userName = "Rli"
        value.onboarded = true
        value.nudgeLowBalance = false
        value.nudgeDailyLog = false
        return value
    }
}
