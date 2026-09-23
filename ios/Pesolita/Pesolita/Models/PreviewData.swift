import Foundation

#if DEBUG
extension WalletSnapshot {
    static var simulatorDemo: WalletSnapshot {
        let everyday = Card(
            id: "card_everyday",
            kind: .debit,
            nick: "Main Account",
            last4: "4821",
            exp: "12 / 30",
            bal: 8_425.50,
            limit: 15_000,
            art: CardTemplates.byID["banks/template_007"]!.art,
            frozen: false,
            accountNumber: "0012 4821 7700"
        )
        let wallet = Card(
            id: "card_wallet",
            kind: .eWallet,
            nick: "Daily Wallet",
            last4: "1128",
            exp: "—",
            bal: 2_180,
            limit: 5_000,
            art: CardTemplates.byID["e-wallets/template_047"]!.art,
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
            Transaction(id: "tx_1", cardId: everyday.id, merchant: "Corner Cafe", cat: .food, amount: -245, at: now - 3_600_000, note: "Lunch"),
            Transaction(id: "tx_2", cardId: wallet.id, merchant: "Ride share", cat: .transport, amount: -189, at: now - 8_200_000, note: "Ride home"),
            Transaction(id: "tx_3", cardId: everyday.id, merchant: "Salary", cat: .bills, amount: 12_000, at: now - 86_400_000, note: "Payday"),
            Transaction(id: "tx_4", cardId: everyday.id, merchant: "Electric bill", cat: .bills, amount: -1_870, at: now - 172_800_000, note: "Electric bill"),
            Transaction(id: "tx_5", cardId: cash.id, merchant: "Supermarket", cat: .groceries, amount: -840, at: now - 259_200_000, note: "Weekly groceries"),
            Transaction(id: "tx_6", cardId: wallet.id, merchant: "Mobile load", cat: .load, amount: -99, at: now - 345_600_000, note: "Prepaid top-up"),
        ]
        value.activeId = everyday.id
        value.userName = "Rli"
        value.onboarded = true
        value.nudgeDailyLog = false
        return value
    }

    /// A fuller wallet used only for store screenshots. Kept separate from `simulatorDemo`
    /// so the UI tests that assert on specific card ids keep seeing exactly three cards.
    static var simulatorShowcase: WalletSnapshot {
        var value = WalletSnapshot.simulatorDemo
        let credit = Card(
            id: "card_credit",
            kind: .credit,
            nick: "Rewards Card",
            last4: "9043",
            exp: "08 / 29",
            bal: 26_400,
            limit: 40_000,
            art: CardTemplates.byID["credit-cards/template_032"]!.art,
            frozen: false
        )
        let savings = Card(
            id: "card_savings",
            kind: .digitalBank,
            nick: "Savings",
            last4: "3317",
            exp: "—",
            bal: 54_120.75,
            limit: 0,
            art: CardTemplates.byID["digital-banks/template_042"]!.art,
            frozen: false
        )
        value.cards.insert(credit, at: 1)
        value.cards.append(savings)
        value.homeLayout = .stack
        return value
    }

    /// The wallet in the App Store screenshots. Every card uses Pesolita's own generated art —
    /// never an issuer-style template — so no bank's branding appears in store metadata.
    /// A trip in progress, friends who owe (some already paid back) and ordinary spending.
    static var storeShowcase: WalletSnapshot {
        let now = Date().timeIntervalSince1970 * 1_000
        let hour = 3_600_000.0, day = 86_400_000.0
        func art(_ style: CardArtStyle, _ c1: String, _ c2: String, _ tex: CardTexture = .none, chip: Bool = true, tier: String? = nil) -> CardArt {
            var a = CardArt(style: style, c1: c1, c2: c2, tex: tex, layout: .standard)
            a.chip = chip
            a.tier = tier
            return a
        }
        let main = Card(id: "card_main", kind: .debit, nick: "Main Account", last4: "4821", exp: "12 / 30",
                        bal: 18_425.50, limit: 20_000, art: art(.wave, "#1d6ff2", "#0b3a8f", .dots), frozen: false)
        let wallet = Card(id: "card_wallet", kind: .eWallet, nick: "Daily Wallet", last4: "1128", exp: "—",
                          bal: 3_180, limit: 5_000, art: art(.blob, "#0b8f6a", "#f4eedc", .grain, chip: false), frozen: false)
        let credit = Card(id: "card_credit", kind: .credit, nick: "Rewards Card", last4: "9043", exp: "08 / 29",
                          bal: 26_400, limit: 40_000, art: art(.metal, "#0b0b0c", "#ffca28", tier: "Gold"), frozen: false)
        let travel = Card(id: "card_travel", kind: .savings, nick: "Travel Fund", last4: "", exp: "—",
                          bal: 12_750, limit: 0, art: art(.orbit, "#7c3aed", "#f9a8b4", chip: false), frozen: false, goal: 30_000)
        let cash = Card(id: "card_cash", kind: .cash, nick: "Cash on Hand", last4: "", exp: "—",
                        bal: 1_860, limit: 3_000, art: .cash, frozen: false)

        let people = [
            Person(id: "p-migo", name: "Migo", color: "#1d6ff2"),
            Person(id: "p-bea", name: "Bea", color: "#0b8f6a"),
            Person(id: "p-jr", name: "JR", color: "#f0483e"),
            Person(id: "p-ana", name: "Ana", color: "#7c3aed"),
            Person(id: "p-kat", name: "Kat", color: "#ffca28"),
        ]
        let thai = EventGroup(id: "e-thai", name: "Day 1 Thailand", emoji: "🇹🇭", startedAt: now - 2 * day,
                              memberIds: ["p-migo", "p-bea", "p-jr", "p-ana"])
        let baguio = EventGroup(id: "e-baguio", name: "Baguio weekend", emoji: "🌲", startedAt: now - 30 * day,
                                endedAt: now - 28 * day, memberIds: ["p-kat", "p-bea"])

        func part(_ id: String, _ name: String, _ amount: Double, settled: Double? = nil, by tx: String? = nil) -> SplitPart {
            SplitPart(personId: id, name: name, amount: amount, settledAt: settled, settledTxId: tx)
        }
        var value = WalletSnapshot()
        value.cards = [main, wallet, credit, travel, cash]
        value.people = people
        value.events = [thai, baguio]
        value.tx = [
            Transaction(id: "s-dinner", cardId: main.id, merchant: "Beach dinner", cat: .food, amount: -3_600,
                        at: now - 1 * hour, note: "Seafood by the pier", eventId: thai.id,
                        split: Split(mode: .even, mine: 720, parts: [
                            part("p-migo", "Migo", 720), part("p-bea", "Bea", 720),
                            part("p-jr", "JR", 720), part("p-ana", "Ana", 720)])),
            Transaction(id: "s-tuktuk", cardId: wallet.id, merchant: "Tuk-tuk ride", cat: .transport, amount: -480,
                        at: now - 4 * hour, note: "", eventId: thai.id,
                        split: Split(mode: .even, mine: 120, parts: [
                            part("p-migo", "Migo", 120), part("p-bea", "Bea", 120), part("p-jr", "JR", 120)])),
            Transaction(id: "r-bea", cardId: main.id, merchant: "Bea paid you back", cat: .bills, amount: 1_500,
                        at: now - 5 * hour, note: "Island hopping", repaysTxId: "s-island"),
            Transaction(id: "s-island", cardId: main.id, merchant: "Island hopping", cat: .fun, amount: -6_000,
                        at: now - 9 * hour, note: "Boat for four", eventId: thai.id,
                        split: Split(mode: .even, mine: 1_500, parts: [
                            part("p-migo", "Migo", 1_500), part("p-bea", "Bea", 1_500, settled: now - 5 * hour, by: "r-bea"),
                            part("p-jr", "JR", 1_500)])),
            Transaction(id: "s-street", cardId: cash.id, merchant: "Night market", cat: .food, amount: -1_240,
                        at: now - 1 * day, note: "Pad thai + mango sticky rice", eventId: thai.id,
                        split: Split(mode: .even, mine: 310, parts: [
                            part("p-migo", "Migo", 310), part("p-bea", "Bea", 310), part("p-jr", "JR", 310)])),
            Transaction(id: "t-coffee", cardId: wallet.id, merchant: "Corner Cafe", cat: .food, amount: -185,
                        at: now - 1 * day - 3 * hour, note: "Iced latte"),
            Transaction(id: "t-salary", cardId: main.id, merchant: "Salary", cat: .bills, amount: 25_000,
                        at: now - 3 * day, note: "Payday"),
            Transaction(id: "t-grocery", cardId: cash.id, merchant: "Supermarket", cat: .groceries, amount: -1_120,
                        at: now - 4 * day, note: "Weekly groceries"),
            Transaction(id: "t-load", cardId: wallet.id, merchant: "Mobile load", cat: .load, amount: -99,
                        at: now - 5 * day, note: ""),
            Transaction(id: "t-electric", cardId: main.id, merchant: "Electric bill", cat: .bills, amount: -2_140,
                        at: now - 6 * day, note: ""),
            Transaction(id: "s-baguio", cardId: main.id, merchant: "Strawberry farm", cat: .fun, amount: -900,
                        at: now - 29 * day, note: "", eventId: baguio.id,
                        split: Split(mode: .even, mine: 300, parts: [
                            part("p-kat", "Kat", 300, settled: now - 27 * day), part("p-bea", "Bea", 300, settled: now - 27 * day)])),
        ]
        value.activeId = main.id
        value.userName = "Rli"
        value.onboarded = true
        value.homeLayout = .deck
        value.nudgeDailyLog = false
        return value
    }
}
#endif

#if DEBUG
/// Set while capturing App Store screenshots, so developer-only controls stay out of frame.
enum StoreCapture {
    nonisolated(unsafe) static var active = false
}
#endif
