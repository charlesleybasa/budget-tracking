import Foundation

struct WidgetWalletPayload: Codable, Equatable, Sendable {
    var version: Int
    var cards: [WidgetCardPayload]
    var transactions: [WidgetTransactionPayload]
    var activeCardID: String
    var totalBalance: Double
    var privacyEnabled: Bool
    var updatedAt: Double

    static let empty = WidgetWalletPayload(
        version: 1,
        cards: [],
        transactions: [],
        activeCardID: "",
        totalBalance: 0,
        privacyEnabled: false,
        updatedAt: Date().timeIntervalSince1970
    )

    static let placeholder = WidgetWalletPayload(
        version: 1,
        cards: [
            WidgetCardPayload(
                id: "preview-bdo",
                name: "BDO Debit",
                kind: "ATM / Debit",
                balance: 8_425.50,
                safeToday: 472.60,
                frozen: false,
                last4: "4821",
                primaryHex: "#011966",
                secondaryHex: "#ffffff",
                artStyle: "photo",
                templatePath: "banks/bdo-debit.webp",
                useDarkText: false
            ),
            WidgetCardPayload(
                id: "preview-cash",
                name: "Cash on Hand",
                kind: "Cash on hand",
                balance: 760,
                safeToday: 100,
                frozen: false,
                last4: "",
                primaryHex: "#ffca28",
                secondaryHex: "#0b0b0c",
                artStyle: "blob",
                templatePath: nil,
                useDarkText: true
            )
        ],
        transactions: [
            WidgetTransactionPayload(
                id: "preview-transaction",
                cardID: "preview-bdo",
                merchant: "Jollibee",
                category: "Food",
                amount: -245,
                timestamp: Date().addingTimeInterval(-3_600).timeIntervalSince1970 * 1_000
            )
        ],
        activeCardID: "preview-bdo",
        totalBalance: 9_185.50,
        privacyEnabled: false,
        updatedAt: Date().timeIntervalSince1970
    )
}

struct WidgetCardPayload: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var kind: String
    var balance: Double
    var safeToday: Double
    var frozen: Bool
    var last4: String
    var primaryHex: String
    var secondaryHex: String
    var artStyle: String
    var templatePath: String?
    var useDarkText: Bool
}

struct WidgetTransactionPayload: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var cardID: String
    var merchant: String
    var category: String
    var amount: Double
    var timestamp: Double
}

enum WidgetSharedStore {
    static let appGroup = "group.com.pesolita.app"
    static let payloadKey = "pesolita.widget.wallet.v1"
    static let selectedCardKey = "pesolita.widget.selected-card"
    static let widgetKind = "PesolitaPocketWidget"

    static func loadPayload() -> WidgetWalletPayload {
        guard let data = defaults.data(forKey: payloadKey),
              let payload = try? JSONDecoder().decode(WidgetWalletPayload.self, from: data) else {
            return .empty
        }
        return payload
    }

    static func selectedCardID(in payload: WidgetWalletPayload) -> String {
        let stored = defaults.string(forKey: selectedCardKey)
        if let stored, payload.cards.contains(where: { $0.id == stored }) { return stored }
        if payload.cards.contains(where: { $0.id == payload.activeCardID }) { return payload.activeCardID }
        return payload.cards.first?.id ?? ""
    }

    static func moveSelection(by offset: Int) {
        let payload = loadPayload()
        guard payload.cards.count > 1 else { return }
        let currentID = selectedCardID(in: payload)
        let currentIndex = payload.cards.firstIndex(where: { $0.id == currentID }) ?? 0
        let nextIndex = (currentIndex + offset + payload.cards.count) % payload.cards.count
        defaults.set(payload.cards[nextIndex].id, forKey: selectedCardKey)
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}

enum WidgetRoute {
    static func url(_ action: String, cardID: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "pesolita"
        components.host = action
        if let cardID { components.queryItems = [URLQueryItem(name: "card", value: cardID)] }
        return components.url ?? URL(string: "pesolita://card")!
    }
}
