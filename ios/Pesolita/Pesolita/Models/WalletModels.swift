import Foundation
import SwiftUI
enum CardArtStyle: String, Codable, CaseIterable, Sendable {
    case blob, wave, arc, grid, confetti, mesh, planes, metal, glyph, orbit, foil, irid, crest, photo
}

enum ScrimKey: String, Codable, CaseIterable, Sendable { case off, soft, strong, veil }
enum TextMode: String, Codable, CaseIterable, Sendable { case auto, light, dark }
enum CardTexture: String, Codable, CaseIterable, Sendable { case none, grain, dots, stripes }
enum CardLayout: String, Codable, Sendable { case standard, compact }
enum HomeLayout: String, Codable, Sendable { case deck, stack }

struct RGBSample: Codable, Hashable, Sendable {
    var red: Int
    var green: Int
    var blue: Int
}

struct PhotoArt: Codable, Hashable, Sendable {
    var src: String
    var zoom: Double = 1
    var px: Double = 0
    var py: Double = 0
    var scrim: ScrimKey = .off
    var blur: Bool = false
    var textMode: TextMode = .auto
    var sample: RGBSample = .init(red: 11, green: 11, blue: 12)
}

struct CardArt: Codable, Hashable, Sendable {
    var style: CardArtStyle
    var c1: String
    var c2: String
    var tex: CardTexture
    var layout: CardLayout
    var chip: Bool = false
    var tier: String?
    var glyph: String?
    var photo: PhotoArt?

    static let cash = CardArt(
        style: .blob,
        c1: "#ffca28",
        c2: "#0b0b0c",
        tex: .grain,
        layout: .standard
    )
}

enum TemplateCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case banks
    case creditCards = "credit-cards"
    case digitalBanks = "digital-banks"
    case eWallets = "e-wallets"
    case membership
    case prepaid

    var id: String { rawValue }
    var label: String {
        switch self {
        case .banks: "Banks"
        case .creditCards: "Credit Cards"
        case .digitalBanks: "Digital Banks"
        case .eWallets: "E-wallets"
        case .membership: "Membership"
        case .prepaid: "Prepaid"
        }
    }
}

struct CardTemplate: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var category: TemplateCategory
    var resourcePath: String
    var focalX: Double
    var focalY: Double
    var sample: RGBSample
    var fallbackHex: String
    var scrim: ScrimKey
    var textMode: TextMode
    var chip: Bool

    var art: CardArt {
        CardArt(
            style: .photo,
            c1: fallbackHex,
            c2: "#ffffff",
            tex: .none,
            layout: .standard,
            chip: chip,
            photo: PhotoArt(
                src: "template:\(resourcePath)",
                zoom: 1,
                px: focalX,
                py: focalY,
                scrim: scrim,
                blur: false,
                textMode: textMode,
                sample: sample
            )
        )
    }
}

enum CardKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case debit = "ATM / Debit"
    case credit = "Credit card"
    case digitalBank = "Digital wallet"
    case cash = "Cash on hand"
    case eWallet = "E-wallet"
    case membership = "Membership card"
    case prepaid = "Prepaid card"
    case savings = "Savings goal"
    case emergency = "Emergency fund"
    case shared = "Shared"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .debit: "Debit"
        case .credit: "Credit card"
        case .digitalBank: "Digital wallet"
        case .cash: "Cash on hand"
        case .eWallet: "E-wallet"
        case .membership: "Membership"
        case .prepaid: "Prepaid"
        case .savings: "Savings goal"
        case .emergency: "Emergency fund"
        case .shared: "Shared pocket"
        }
    }
    var hint: String {
        switch self {
        case .debit: "ATM and debit cards"
        case .credit: "Borrowed money"
        case .digitalBank: "App-first accounts"
        case .cash: "Actual paper"
        case .eWallet: "Pay by app"
        case .membership: "Rewards and loyalty"
        case .prepaid: "Load it before use"
        case .savings: "Money with a job"
        case .emergency: "Do not touch"
        case .shared: "Money together"
        }
    }
    /// Distinct glyph per kind so the onboarding chips read at a glance rather than
    /// showing seven identical card icons.
    var symbol: String {
        switch self {
        case .debit: "creditcard"
        case .credit: "creditcard.fill"
        case .digitalBank: "building.columns"
        case .cash: "banknote"
        case .eWallet: "iphone"
        case .membership: "star.circle"
        case .prepaid: "arrow.clockwise.circle"
        case .savings: "target"
        case .emergency: "shield"
        case .shared: "person.2"
        }
    }

    var templateCategory: TemplateCategory? {
        switch self {
        case .debit: .banks
        case .credit: .creditCards
        case .digitalBank: .digitalBanks
        case .eWallet: .eWallets
        case .membership: .membership
        case .prepaid: .prepaid
        default: nil
        }
    }

    static let onboardingKinds: [CardKind] = [.debit, .credit, .digitalBank, .cash, .eWallet, .membership, .prepaid]
}

struct Card: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var kind: CardKind
    var nick: String
    var last4: String
    var exp: String
    var bal: Double
    var limit: Double
    var art: CardArt
    var frozen: Bool
    var goal: Double?
    var accountNumber: String?
    var qr: String?
}

enum CategoryName: String, Codable, CaseIterable, Identifiable, Sendable {
    case food = "Food"
    case transport = "Transport"
    case bills = "Bills"
    case groceries = "Groceries"
    case shopping = "Shopping"
    case load = "Load"
    case health = "Health"
    case fun = "Fun"

    var id: String { rawValue }
    var colorHex: String {
        switch self {
        case .food: "#f0483e"
        case .transport: "#1d6ff2"
        case .bills: "#7c3aed"
        case .groceries: "#0b8f6a"
        case .shopping: "#ffca28"
        case .load: "#ec4899"
        case .health: "#0891b2"
        case .fun: "#f97316"
        }
    }
}

/// Someone a spend can be split with. Local to the device — no account behind it, no invite
/// and no network call, which is what lets splitting exist in an offline wallet.
struct Person: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    /// Avatar colour, paired with the initial so nobody has to upload a photo.
    var color: String
    /// GCash number or handle. Only ever used to prefill a reminder message.
    var handle: String?
    var photoSrc: String?
    var archived: Bool = false
}

/// A trip, a night out, a shared household month — the container a spend can belong to.
struct EventGroup: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var emoji: String
    var startedAt: Double
    /// Nil while the event is still running.
    var endedAt: Double?
    /// Pre-selected on every spend logged while this event is open.
    var memberIds: [String] = []
}

enum SplitMode: String, Codable, Sendable { case even, shares, exact, theirs }

/// One person's slice of one spend.
struct SplitPart: Codable, Identifiable, Hashable, Sendable {
    var personId: String
    /// The person's name as it was when the split was saved. A snapshot rather than a lookup,
    /// because deleting a person must never rewrite what a night actually cost.
    var name: String
    /// What they owe, in pesos. Always stored resolved — never a ratio or a percentage.
    var amount: Double
    var shares: Int?
    var settledAt: Double?
    /// The top-up that settling created, so un-settling can reverse exactly that.
    var settledTxId: String?
    var id: String { personId }
}

/// The split carried by a transaction. `mine` is stored rather than derived so the rounding
/// remainder is decided once, at save time, instead of drifting between call sites.
struct Split: Codable, Hashable, Sendable {
    var mode: SplitMode = .even
    /// The wallet owner's own share. This, not `amount`, is what spend analytics count.
    var mine: Double
    var parts: [SplitPart] = []
}

struct Transaction: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var cardId: String
    var merchant: String
    var cat: CategoryName
    var amount: Double
    var at: Double
    var note: String
    var receipt: String?
    /// The event this belongs to, when it was logged inside one.
    var eventId: String?
    /// Set when part of this spend was other people's. `amount` stays the full figure — the
    /// card really did lose that much — and `split.mine` is what every spend analytic counts.
    var split: Split?
    /// Set on a settlement top-up, pointing back at the spend it repays.
    var repaysTxId: String?
}

struct WalletSnapshot: Codable, Sendable, Equatable {
    /// 2 adds people, events and splits. Older snapshots decode with the new collections
    /// simply empty, so a Pro device syncing from an older build still loads cleanly.
    var schemaVersion = 2
    var cards: [Card] = []
    var tx: [Transaction] = []
    var people: [Person] = []
    var events: [EventGroup] = []
    var dismissedNotices: [String] = []
    var activeId = ""
    var userName = ""
    var privacy = false
    var widgetPrivacy = false
    var homeLayout: HomeLayout = .deck
    var onboarded = false
    var nudgeDailyLog = false
    var haptics = true
    var sfx = true
    var userPhotoSrc: String?
    var appTheme: AppTheme = .system
    /// Stamped only on the copy written to the cloud: when it was saved, in epoch ms, and on
    /// which device. The local wallet never carries these — setting them locally would itself
    /// count as a change and trigger another upload.
    var savedAt: Double?
    var savedOn: String?

    static let empty = WalletSnapshot()

    /// True when there is nothing in it worth protecting — used so an empty wallet is never
    /// allowed to overwrite a real one in the cloud.
    var isEffectivelyEmpty: Bool { cards.isEmpty && tx.isEmpty && people.isEmpty && events.isEmpty }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, cards, tx, people, events, dismissedNotices, activeId, userName, privacy, widgetPrivacy
        case homeLayout, onboarded, nudgeDailyLog, haptics, sfx, userPhotoSrc, appTheme
        case savedAt, savedOn
    }

    init() {}

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try box.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        cards = try box.decodeIfPresent([Card].self, forKey: .cards) ?? []
        tx = try box.decodeIfPresent([Transaction].self, forKey: .tx) ?? []
        people = try box.decodeIfPresent([Person].self, forKey: .people) ?? []
        events = try box.decodeIfPresent([EventGroup].self, forKey: .events) ?? []
        dismissedNotices = try box.decodeIfPresent([String].self, forKey: .dismissedNotices) ?? []
        activeId = try box.decodeIfPresent(String.self, forKey: .activeId) ?? cards.first?.id ?? ""
        userName = try box.decodeIfPresent(String.self, forKey: .userName) ?? ""
        privacy = try box.decodeIfPresent(Bool.self, forKey: .privacy) ?? false
        widgetPrivacy = try box.decodeIfPresent(Bool.self, forKey: .widgetPrivacy) ?? false
        homeLayout = try box.decodeIfPresent(HomeLayout.self, forKey: .homeLayout) ?? .deck
        onboarded = try box.decodeIfPresent(Bool.self, forKey: .onboarded) ?? !cards.isEmpty
        nudgeDailyLog = try box.decodeIfPresent(Bool.self, forKey: .nudgeDailyLog) ?? false
        haptics = try box.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        sfx = try box.decodeIfPresent(Bool.self, forKey: .sfx) ?? true
        userPhotoSrc = try box.decodeIfPresent(String.self, forKey: .userPhotoSrc)
        appTheme = try box.decodeIfPresent(AppTheme.self, forKey: .appTheme) ?? .system
        savedAt = try box.decodeIfPresent(Double.self, forKey: .savedAt)
        savedOn = try box.decodeIfPresent(String.self, forKey: .savedOn)
        let valid = Set(cards.map(\.id))
        tx.removeAll { !valid.contains($0.cardId) }
        if !valid.contains(activeId) { activeId = cards.first?.id ?? "" }

        // A split whose parts no longer add up would quietly misreport what the user spent,
        // so it is dropped rather than trusted. The transaction survives at its full amount:
        // wrong about who owed what, never wrong about the money.
        let knownEvents = Set(events.map(\.id))
        for i in tx.indices {
            if let eventId = tx[i].eventId, !knownEvents.contains(eventId) { tx[i].eventId = nil }
            guard let split = tx[i].split else { continue }
            let others = split.parts.reduce(0) { $0 + max(0, $1.amount) }
            if split.parts.isEmpty || others + split.mine > abs(tx[i].amount) + 0.5 {
                tx[i].split = nil
            }
        }
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum MainTab: String, CaseIterable, Identifiable, Sendable {
    case home, insights, search, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .home: "house"
        case .insights: "chart.bar"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
    var selectedSymbol: String {
        switch self {
        case .home: "house.fill"
        case .insights: "chart.bar.fill"
        case .search: "magnifyingglass"
        case .settings: "gearshape.fill"
        }
    }
}

enum TransactionSheetKind: String, Codable, Sendable { case withdraw, deposit, move }

enum SearchFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case moneyIn = "Money in"
    case moneyOut = "Money out"
    case split = "Split"
    case food = "Food"
    case transport = "Transport"
    case bills = "Bills"
    case groceries = "Groceries"
    case shopping = "Shopping"
    case load = "Load"
    case health = "Health"
    case fun = "Fun"

    var id: String { rawValue }
    var category: CategoryName? { CategoryName(rawValue: rawValue) }
}

enum InsightPeriod: String, CaseIterable, Identifiable, Sendable {
    case week, month, all
    var id: String { rawValue }
    var label: String { self == .week ? "This week" : self == .month ? "This month" : "All time" }
    var days: Int? { self == .week ? 7 : self == .month ? 30 : nil }
}

enum AppRoute: Hashable, Sendable {
    case detail(String)
    case editor(String?)
    case transfer
    case people
    case events
    case event(String)
}

extension String {
    /// Nil for an empty string, so an untouched optional field stays absent rather than "".
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

enum EditorMode: String, CaseIterable, Identifiable, Sendable {
    case templates, diy
    var id: String { rawValue }
}

struct CardEditorDraft: Sendable {
    var card: Card
    var isNew: Bool
    var mode: EditorMode
    var templateArt: CardArt
    var diyArt: CardArt
}

struct TransactionEditorDraft: Sendable {
    var transactionID: String
    var amount: String
    var category: CategoryName
    var note: String
    var receipt: String?
}

struct SuccessState: Identifiable, Sendable, Equatable {
    enum Kind: String, Sendable { case funded, logged, moved }
    let id = UUID()
    var kind: Kind
    var head: String
    var body: String
}

struct OnboardingDraft: Sendable {
    var step = 0
    var name = ""
    var kind: CardKind?
    var nickname = ""
    var balance = ""
    var art = CardArt.cash
    var templateID: String?
}
