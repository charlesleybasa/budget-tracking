import Foundation
import Observation

@MainActor
@Observable
final class WalletStore {
    private(set) var snapshot: WalletSnapshot = .empty
    var onboarding = OnboardingDraft()
    var selectedTab: MainTab = .home
    var path: [AppRoute] = []
    var sheet: TransactionSheetKind?
    var success: SuccessState?
    var amountDraft = ""
    var noteDraft = ""
    var categoryDraft: CategoryName = .food
    var receiptDraft: String?
    var sheetCardID = ""
    var moveToCardID = ""
    var transferFromID = ""
    var transferToID = ""
    var editor: CardEditorDraft?
    var transactionEditor: TransactionEditorDraft?
    var searchQuery = ""
    var searchFilter: SearchFilter = .all
    var isScrolledDown = false

    // Split draft — part of the transaction sheet, not a screen of its own.
    /// People this spend is being split with. Empty means "just me", the default.
    var splitWith: [String] = []
    var splitMode: SplitMode = .even
    var splitShares: [String: Int] = [:]
    /// Exact mode, held as typed text so a half-typed "12." survives a keystroke.
    var splitExact: [String: String] = [:]
    /// Event this spend will be tagged with, or nil.
    var sheetEventID: String?
    /// The event open on the event detail screen.
    var openEventID: String?

    /// The settlement waiting on slide-to-confirm, or nil. Getting paid back moves real money
    /// into a real card, so it asks for a deliberate gesture rather than a tap that can happen
    /// by accident in a pocket. An empty `txID` means "everything this person owes".
    var pendingSettle: PendingSettle?
    var qrViewerCardID: String?
    var receiptViewerTransactionID: String?
    var activeTransaction: Transaction? = nil
    var isPro: Bool = UserDefaults.standard.bool(forKey: "isPro") {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "isPro")
        }
    }
    var showProUpsell: Bool = false
    /// The Continue-with-Google restore flow. One sheet, opened from onboarding, Settings, the
    /// Home banner and the Pro sheet, so every entry point handles every case the same way.
    var restoreFlowOpen = false
    /// Whether the flow should go straight to Google rather than offering the choice first.
    var restoreFlowStartsSignIn = false

    func openRestoreFlow(startSignIn: Bool = false) {
        restoreFlowStartsSignIn = startSignIn
        restoreFlowOpen = true
    }
    var cardDeleteOpen = false
    var eraseOpen = false
    var toast: String?
    var loadError: String?
    private(set) var hydrated = false
    private var pendingDeepLink: URL?

    private let repository: WalletRepository?
    let mediaStore: MediaStore
    private var toastTask: Task<Void, Never>?

    init(
        snapshot: WalletSnapshot = .empty,
        repository: WalletRepository? = WalletRepository(),
        mediaStore: MediaStore = MediaStore()
    ) {
        self.snapshot = snapshot
        self.repository = repository
        self.mediaStore = mediaStore
        FeedbackCenter.configure(haptics: snapshot.haptics, sounds: snapshot.sfx)
    }

    var activeCard: Card? {
        snapshot.cards.first { $0.id == snapshot.activeId } ?? snapshot.cards.first
    }

    var totalBalance: Double { snapshot.cards.reduce(0) { $0 + $1.bal } }

    var recentTransactions: [Transaction] {
        Array(snapshot.tx.sorted { $0.at > $1.at }.prefix(4))
    }

    var searchResults: [Transaction] {
        WalletMetrics.search(snapshot.tx, query: searchQuery, filter: searchFilter)
    }

    var transferFromCard: Card? { snapshot.cards.first { $0.id == transferFromID } ?? activeCard }
    var transferToCard: Card? { snapshot.cards.first { $0.id == transferToID } }
    var moveToCard: Card? { snapshot.cards.first { $0.id == moveToCardID } }

    var sheetCard: Card? {
        snapshot.cards.first { $0.id == sheetCardID } ?? activeCard
    }

    var typedAmount: Double { Double(amountDraft) ?? 0 }

    /// The people currently selected, in the order the user picked them.
    var selectedPeople: [Person] {
        splitWith.compactMap { id in snapshot.people.first { $0.id == id } }
    }

    /// The split the current draft describes, or nil when the spend is just the user's.
    /// Built on demand rather than kept in state, so the keypad and the people picker can
    /// never disagree about what the split currently is.
    var draftSplit: Split? {
        guard sheet == .withdraw else { return nil }
        let amounts = splitExact.compactMapValues { Double($0) }
        return SplitMath.build(mode: splitMode, total: typedAmount, people: selectedPeople,
                               shares: splitShares, amounts: amounts)
    }

    var debts: [PersonDebt] { SplitMath.debts(transactions: snapshot.tx, people: snapshot.people) }
    var totalOwed: Double { SplitMath.totalOwed(snapshot.tx) }
    var openEvent: EventGroup? { EventMetrics.find(snapshot.events, id: openEventID) }

    /// The debt the pending gesture would clear, scoped to exactly what it covers so the
    /// figure on screen matches the money that will move.
    var pendingDebt: PersonDebt? {
        guard let pendingSettle else { return nil }
        let scoped = pendingSettle.txID.isEmpty
            ? snapshot.tx
            : snapshot.tx.filter { $0.id == pendingSettle.txID }
        return SplitMath.debts(transactions: scoped, people: snapshot.people)
            .first { $0.personId == pendingSettle.personID }
    }

    /// The card a pending settlement would land in.
    var pendingSettleCard: Card? {
        guard let pendingSettle else { return nil }
        let scoped = pendingSettle.txID.isEmpty
            ? snapshot.tx
            : snapshot.tx.filter { $0.id == pendingSettle.txID }
        let source = scoped.first {
            $0.split?.parts.contains { $0.personId == pendingSettle.personID && $0.settledAt == nil } ?? false
        }
        return snapshot.cards.first { $0.id == source?.cardId }
    }
    var spendOverage: Double {
        guard sheet == .withdraw, let card = sheetCard else { return 0 }
        return max(0, typedAmount - card.bal)
    }
    var canSubmitTransaction: Bool {
        guard let card = sheetCard, typedAmount > 0 else { return false }
        if sheet == .withdraw { return !card.frozen && card.bal > 0 && spendOverage == 0 }
        if sheet == .move { return moveToCard != nil && moveToCardID != card.id && typedAmount <= card.bal }
        return sheet == .deposit
    }

    func load() async {
        defer {
            FeedbackCenter.configure(haptics: snapshot.haptics, sounds: snapshot.sfx)
            hydrated = true
            WidgetSnapshotPublisher.publish(snapshot)
            if let pendingDeepLink {
                self.pendingDeepLink = nil
                handleDeepLink(pendingDeepLink)
            }
        }
        guard let repository else { return }
#if DEBUG
        // Every launch-argument hook below exists only for the UI tests and the store-asset
        // captures. The read itself is inside the guard so a shipping build never inspects
        // its launch arguments at all.
        let launchArguments = ProcessInfo.processInfo.arguments
        if launchArguments.contains("--demo-wallet") {
            try? await repository.erase()
            snapshot = launchArguments.contains("--showcase") ? .simulatorShowcase : .simulatorDemo
            if launchArguments.contains("--empty-activity") { snapshot.tx = [] }
            if launchArguments.contains("--with-friends"), let card = snapshot.cards.first?.id {
                let now = Date().timeIntervalSince1970 * 1000
                let friends = [("p-migo", "Migo", "#1d6ff2"), ("p-bea", "Bea", "#0b8f6a"),
                               ("p-jr", "JR", "#f0483e"), ("p-ana", "Ana", "#7c3aed")]
                snapshot.people = friends.map { Person(id: $0.0, name: $0.1, color: $0.2) }
                snapshot.events = [EventGroup(id: "e-thai", name: "Day 1 Thailand", emoji: "🇹🇭", startedAt: now - 86_400_000,
                                              memberIds: friends.map(\.0))]
                snapshot.tx.insert(Transaction(id: "t-dinner", cardId: card, merchant: "Beach dinner", cat: .food,
                                               amount: -2_500, at: now - 3_600_000, note: "", eventId: "e-thai",
                                               split: Split(mode: .even, mine: 500, parts: friends.map {
                                                   SplitPart(personId: $0.0, name: $0.1, amount: 500)
                                               })), at: 0)
            }
            if launchArguments.contains("--layout=stack") { snapshot.homeLayout = .stack }
            if launchArguments.contains("--tab=insights") { selectedTab = .insights }
            if launchArguments.contains("--tab=search") { selectedTab = .search }
            if launchArguments.contains("--tab=settings") { selectedTab = .settings }
            if launchArguments.contains("--open-pro") { selectedTab = .settings; showProUpsell = true }
            if launchArguments.contains("--open-restore") { openRestoreFlow() }
            synchronizeEndpoints()
            if launchArguments.contains("--route=detail") {
                path = [.detail(snapshot.activeId)]
            } else if launchArguments.contains("--route=transfer") {
                transferFromID = snapshot.activeId
                transferToID = snapshot.cards.first { $0.id != snapshot.activeId }?.id ?? ""
                path = [.transfer]
            } else if launchArguments.contains("--route=editor") {
                openEditor(cardID: snapshot.activeId)
            }
            return
        }
        // Inside the debug guard on purpose. A shipping build must expose no way to erase
        // someone's wallet that is not visible in the interface — an undocumented launch
        // argument that destroys data is indistinguishable from a deliberately hidden
        // feature, which is what Guideline 5.6 prohibits.
        if launchArguments.contains("--reset-wallet") {
            try? await repository.erase()
        }
#endif
        do {
            if let stored = try await repository.load() { snapshot = stored }
            synchronizeEndpoints()
        } catch {
            loadError = error.localizedDescription
            snapshot = .empty
        }
    }

    /// Picking a category no longer advances a step — category and template share one
    /// screen — so this only re-seeds the draft with that category's first template.
    func selectKind(_ kind: CardKind) {
        onboarding.kind = kind
        if kind == .cash {
            onboarding.nickname = "Cash on Hand"
            onboarding.art = .cash
            onboarding.templateID = nil
            return
        }
        guard let category = kind.templateCategory,
              let first = CardTemplates.all.first(where: { $0.category == category }) else { return }
        onboarding.nickname = first.name
        onboarding.art = first.art
        onboarding.templateID = first.id
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "pesolita" else { return }
        guard hydrated else {
            pendingDeepLink = url
            return
        }

        let action = (url.host ?? url.pathComponents.dropFirst().first ?? "").lowercased()
        let cardID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "card" })?
            .value
        let validCardID = cardID.flatMap { id in snapshot.cards.contains(where: { $0.id == id }) ? id : nil }

        selectedTab = .home
        path.removeAll()
        switch action {
        case "spend":
            openTransaction(.withdraw, cardID: validCardID)
        case "topup":
            openTransaction(.deposit, cardID: validCardID)
        case "card":
            if let validCardID { showCardDetail(validCardID) }
        case "add-card":
            if snapshot.onboarded { openEditor(cardID: nil) }
        case "qr":
            if let validCardID { qrViewerCardID = validCardID }
        case "people":
            path.append(.people)
        case "events":
            path.append(.events)
        case "event":
            let eventID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "id" })?
                .value
            if let eventID, snapshot.events.contains(where: { $0.id == eventID }) {
                openEventDetail(eventID)
            } else {
                path.append(.events)
            }
        default:
            break
        }
    }

    func selectTemplate(_ template: CardTemplate) {
        onboarding.nickname = template.name
        onboarding.art = template.art
        onboarding.templateID = template.id
    }

    func finishOnboarding() {
        let kind = onboarding.kind ?? .debit
        let card = Card(
            id: "card_\(UUID().uuidString.lowercased())",
            kind: kind,
            nick: onboarding.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? kind.rawValue : onboarding.nickname,
            last4: "",
            exp: "—",
            bal: Double(onboarding.balance) ?? 0,
            limit: 0,
            art: onboarding.art,
            frozen: false
        )
        snapshot.cards.append(card)
        snapshot.activeId = card.id
        snapshot.userName = onboarding.name.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.onboarded = true
        transferFromID = card.id
        transferToID = ""
        moveToCardID = ""
        selectedTab = .home
        persist()
        FeedbackCenter.success()
        showToast("Welcome. Log your first spend with the blue button.")
    }

    func setActiveCard(_ id: String) {
        guard snapshot.cards.contains(where: { $0.id == id }) else { return }
        let changed = snapshot.activeId != id
        snapshot.activeId = id
        persist()
        if changed { FeedbackCenter.selectionChanged() }
    }

    func togglePrivacy() {
        snapshot.privacy.toggle()
        persist()
        FeedbackCenter.tap()
        showToast(snapshot.privacy ? "Balances hidden." : "Balances visible.")
    }

    func toggleWidgetPrivacy() {
        snapshot.widgetPrivacy.toggle()
        persist()
        FeedbackCenter.tap()
    }

    func setHomeLayout(_ layout: HomeLayout) {
        snapshot.homeLayout = layout
        persist()
        FeedbackCenter.selectionChanged()
    }

    func setCardLimit(cardID: String, value: Double) {
        guard let index = snapshot.cards.firstIndex(where: { $0.id == cardID }) else { return }
        snapshot.cards[index].limit = max(0, value)
        persist()
        FeedbackCenter.selectionChanged()
    }

    func moveCard(from source: IndexSet, to destination: Int) {
        snapshot.cards.move(fromOffsets: source, toOffset: destination)
        persist()
        FeedbackCenter.selectionChanged()
    }

    func selectTab(_ tab: MainTab) {
        guard selectedTab != tab else { return }
        path.removeAll()
        selectedTab = tab
        FeedbackCenter.selectionChanged()
    }

    func showCardDetail(_ cardID: String) {
        setActiveCard(cardID)
        path.append(.detail(cardID))
        FeedbackCenter.opened()
    }

    func openTransfer(from cardID: String? = nil) {
        guard snapshot.cards.count > 1 else {
            showToast("Add another card before moving money.")
            FeedbackCenter.warning()
            return
        }
        transferFromID = cardID ?? snapshot.activeId
        transferToID = snapshot.cards.first { $0.id != transferFromID }?.id ?? ""
        amountDraft = ""
        path.append(.transfer)
        FeedbackCenter.opened()
    }

    func popRoute() {
        if !path.isEmpty { path.removeLast() }
        FeedbackCenter.closed()
    }

    func openTransaction(_ kind: TransactionSheetKind, cardID: String? = nil) {
        guard !snapshot.cards.isEmpty else {
            showToast("Add a card first.")
            return
        }
        if kind == .move, snapshot.cards.count < 2 {
            showToast("Add another card before moving money.")
            return
        }
        amountDraft = ""
        noteDraft = ""
        categoryDraft = .food
        receiptDraft = nil
        sheetCardID = cardID ?? snapshot.activeId
        moveToCardID = snapshot.cards.first { $0.id != sheetCardID }?.id ?? ""
        clearSplitDraft()
        // A spend logged while an event is running belongs to it unless the user says
        // otherwise — the alternative is tagging every row by hand on a trip. The event
        // carries its members, so the usual crowd is pre-selected on arrival.
        if kind == .withdraw, let running = EventMetrics.running(snapshot.events) {
            sheetEventID = running.id
            splitWith = running.memberIds.filter { id in snapshot.people.contains { $0.id == id } }
        }
        sheet = kind
        FeedbackCenter.opened()
    }

    func changeSheetMode(_ kind: TransactionSheetKind) {
        if kind == .move, snapshot.cards.count < 2 {
            showToast("Add another card before moving money.")
            return
        }
        sheet = kind
        amountDraft = ""
        FeedbackCenter.selectionChanged()
    }

    func dismissSheet() {
        sheet = nil
        receiptDraft = nil
        FeedbackCenter.closed()
    }

    func pressKey(_ key: String) {
        FeedbackCenter.key()
        if key == "⌫" {
            if !amountDraft.isEmpty { amountDraft.removeLast() }
            return
        }
        if key == "." {
            if amountDraft.isEmpty { amountDraft = "0." }
            else if !amountDraft.contains(".") { amountDraft += "." }
            return
        }
        guard key.allSatisfy(\.isNumber) else { return }
        let digits = amountDraft.filter(\.isNumber)
        guard digits.count < 8 else { return }
        if let decimal = amountDraft.firstIndex(of: "."), amountDraft.distance(from: decimal, to: amountDraft.endIndex) > 2 { return }
        amountDraft = amountDraft == "0" ? key : amountDraft + key
    }

    func spendAll() {
        guard let card = sheetCard else { return }
        amountDraft = String(format: "%.2f", card.bal)
    }

    func attachReceipt(_ data: Data, fileExtension: String = "jpg") async {
        do {
            receiptDraft = try await mediaStore.write(data, existingReference: receiptDraft, extension: fileExtension)
            showToast("Receipt attached.")
        } catch {
            showToast("Could not attach that photo.")
        }
    }

    func saveTransaction() {
        guard let kind = sheet, let cardIndex = snapshot.cards.firstIndex(where: { $0.id == sheetCardID }) else {
            showToast("Pick a card first.")
            return
        }
        let card = snapshot.cards[cardIndex]
        guard typedAmount > 0 else {
            showToast("Put a number in first.")
            return
        }
        if kind == .move {
            guard let destinationIndex = snapshot.cards.firstIndex(where: { $0.id == moveToCardID }), destinationIndex != cardIndex else {
                showToast("Pick a different card to move into.")
                FeedbackCenter.warning()
                return
            }
            guard typedAmount <= card.bal else {
                showToast("That is more than \(card.nick) has.")
                FeedbackCenter.warning()
                return
            }
            let destination = snapshot.cards[destinationIndex]
            snapshot.cards[cardIndex].bal -= typedAmount
            snapshot.cards[destinationIndex].bal += typedAmount
            snapshot.tx.insert(Transaction(
                id: "tx_\(UUID().uuidString.lowercased())",
                cardId: destination.id,
                merchant: "From \(card.nick)",
                cat: .bills,
                amount: typedAmount,
                at: Date().timeIntervalSince1970 * 1000,
                note: "Moved"
            ), at: 0)
            sheet = nil
            success = SuccessState(
                kind: .funded,
                head: "Money received.",
                body: "₱\(MoneyFormat.amount(typedAmount)) from \(card.nick) to \(destination.nick). No fees, because everything is offline."
            )
            persist()
            FeedbackCenter.moved()
            return
        }
        if kind == .withdraw, card.frozen {
            showToast("\(card.nick) is frozen. Unfreeze it first.")
            return
        }
        if kind == .withdraw, card.bal <= 0 {
            showToast("\(card.nick) is empty. Top it up first.")
            return
        }
        if kind == .withdraw, typedAmount > card.bal {
            showToast("That is ₱\(MoneyFormat.amount(typedAmount - card.bal)) more than \(card.nick) has.")
            return
        }

        let sign = kind == .deposit ? 1.0 : -1.0
        // Only a spend can be split — money coming in was never anybody else's.
        let split = kind == .withdraw ? draftSplit : nil
        let owed = split?.parts.reduce(0) { $0 + $1.amount } ?? 0

        snapshot.cards[cardIndex].bal += sign * typedAmount
        let transaction = Transaction(
            id: "tx_\(UUID().uuidString.lowercased())",
            cardId: card.id,
            merchant: noteDraft.isEmpty ? (kind == .deposit ? "Top up" : categoryDraft.rawValue) : noteDraft,
            cat: categoryDraft,
            // The card really lost the whole bill, so this stays the full figure. What the
            // user actually spent lives in `split.mine`, and that is what analytics read.
            amount: sign * typedAmount,
            at: Date().timeIntervalSince1970 * 1000,
            note: noteDraft,
            receipt: receiptDraft,
            eventId: kind == .withdraw ? sheetEventID : nil,
            split: split
        )
        snapshot.tx.insert(transaction, at: 0)
        sheet = nil
        receiptDraft = nil
        clearSplitDraft()

        let splitBody: String? = split.map { split in
            let who = split.parts.count == 1 ? split.parts[0].name : "\(split.parts.count) people"
            return "₱\(MoneyFormat.amount(split.mine)) was yours. ₱\(MoneyFormat.amount(owed)) is coming back from \(who)."
        }
        success = SuccessState(
            kind: kind == .deposit ? .funded : .logged,
            head: kind == .deposit ? "Funded." : (split != nil ? "Logged and split." : "Logged it."),
            body: kind == .deposit
                ? "₱\(MoneyFormat.amount(typedAmount)) added to \(card.nick). Look at you, being responsible."
                : splitBody ?? "₱\(MoneyFormat.amount(typedAmount)) off \(card.nick). That took four seconds."
        )
        persist()
        if kind == .deposit { FeedbackCenter.moneyIn() }
        else { FeedbackCenter.moneyOut() }
    }

    func swapTransferCards() {
        (transferFromID, transferToID) = (transferToID, transferFromID)
        FeedbackCenter.snap()
    }

    func performTransfer() {
        guard typedAmount > 0,
              let sourceIndex = snapshot.cards.firstIndex(where: { $0.id == transferFromID }),
              let destinationIndex = snapshot.cards.firstIndex(where: { $0.id == transferToID }),
              sourceIndex != destinationIndex else {
            showToast("Pick two cards and an amount first.")
            FeedbackCenter.warning()
            return
        }
        let source = snapshot.cards[sourceIndex]
        let destination = snapshot.cards[destinationIndex]
        let amount = typedAmount
        guard amount <= source.bal else {
            showToast("That is more than \(source.nick) has.")
            FeedbackCenter.warning()
            return
        }
        snapshot.cards[sourceIndex].bal -= amount
        snapshot.cards[destinationIndex].bal += amount
        snapshot.tx.insert(Transaction(
            id: "tx_\(UUID().uuidString.lowercased())",
            cardId: destination.id,
            merchant: "From \(source.nick)",
            cat: .bills,
            amount: amount,
            at: Date().timeIntervalSince1970 * 1000,
            note: "Transfer"
        ), at: 0)
        amountDraft = ""
        path.removeAll()
        success = SuccessState(
            kind: .moved,
            head: "Money moved.",
            body: "₱\(MoneyFormat.amount(amount)) from \(source.nick) to \(destination.nick). No fees, because everything is offline."
        )
        persist()
        FeedbackCenter.moved()
    }

    func toggleFreeze(cardID: String) {
        guard let index = snapshot.cards.firstIndex(where: { $0.id == cardID }) else { return }
        snapshot.cards[index].frozen.toggle()
        let card = snapshot.cards[index]
        persist()
        FeedbackCenter.toggle(on: !card.frozen)
        showToast(card.frozen ? "\(card.nick) frozen. No spending from it." : "\(card.nick) is live again.")
    }

    func openEditor(cardID: String?) {
        let isNew = cardID == nil
        let card: Card
        if let cardID, let existing = snapshot.cards.first(where: { $0.id == cardID }) {
            card = existing
        } else {
            let template = CardTemplates.all.first!
            card = Card(
                id: "card_\(UUID().uuidString.lowercased())",
                kind: .debit,
                nick: "",
                last4: "",
                exp: "12 / 28",
                bal: 0,
                limit: 0,
                art: template.art,
                frozen: false
            )
        }
        let bundled = card.art.photo?.src.hasPrefix("template:") == true
        editor = CardEditorDraft(
            card: card,
            isNew: isNew,
            mode: bundled ? .templates : .diy,
            templateArt: bundled ? card.art : CardTemplates.all.first!.art,
            diyArt: bundled ? .cash : card.art
        )
        path.append(.editor(cardID))
        FeedbackCenter.opened()
    }

    func setEditorMode(_ mode: EditorMode) {
        guard var editor else { return }
        if editor.mode == .templates { editor.templateArt = editor.card.art }
        else { editor.diyArt = editor.card.art }
        editor.mode = mode
        editor.card.art = mode == .templates ? editor.templateArt : editor.diyArt
        self.editor = editor
        FeedbackCenter.selectionChanged()
    }

    func updateEditorCard(_ change: (inout Card) -> Void) {
        guard var editor else { return }
        change(&editor.card)
        self.editor = editor
    }

    func updateEditorArt(_ change: (inout CardArt) -> Void) {
        guard var editor else { return }
        change(&editor.card.art)
        if editor.mode == .templates { editor.templateArt = editor.card.art }
        else { editor.diyArt = editor.card.art }
        self.editor = editor
    }

    func applyTemplate(_ template: CardTemplate) {
        let previousPath = editor?.card.art.photo?.src
        let previousTemplateName = CardTemplates.all.first { candidate in
            candidate.art.photo?.src == previousPath
        }?.name
        let shouldFollowTemplate = editor?.card.nick.trimmingCharacters(in: .whitespaces).isEmpty == true || editor?.card.nick == previousTemplateName
        updateEditorArt { $0 = template.art }
        if shouldFollowTemplate {
            updateEditorCard { $0.nick = template.name }
        }
        FeedbackCenter.selectionChanged()
    }

    func randomizeEditorArt() {
        let styles = CardArtStyle.allCases.filter { $0 != .photo }
        let palettes: [(String, String)] = [
            ("#ffca28", "#0b0b0c"), ("#1d6ff2", "#f4eedc"), ("#0b8f6a", "#f4eedc"),
            ("#7c3aed", "#f9a8b4"), ("#f0483e", "#ffca28"), ("#0b0b0c", "#ffffff")
        ]
        updateEditorArt { art in
            art.style = styles.randomElement() ?? .blob
            let palette = palettes.randomElement() ?? palettes[0]
            art.c1 = palette.0
            art.c2 = palette.1
            art.tex = CardTexture.allCases.randomElement() ?? .none
            art.photo = nil
        }
        FeedbackCenter.snap()
    }

    func attachEditorImage(_ data: Data, asQR: Bool = false, fileExtension: String = "jpg") async {
        do {
            let existing = asQR ? editor?.card.qr : editor?.card.art.photo?.src
            let reference = try await mediaStore.write(data, existingReference: existing, extension: fileExtension)
            if asQR {
                updateEditorCard { $0.qr = reference }
                showToast("Receiving QR attached.")
            } else {
                updateEditorArt { art in
                    art.style = .photo
                    art.photo = PhotoArt(src: reference, zoom: 1, px: 0, py: 0, scrim: .soft, blur: false, textMode: .auto)
                }
                showToast("Photo added.")
            }
            FeedbackCenter.success()
        } catch {
            showToast("Could not save that image.")
            FeedbackCenter.warning()
        }
    }

    func attachQRToCard(cardID: String, data: Data, fileExtension: String = "jpg") async {
        do {
            let existing = snapshot.cards.first(where: { $0.id == cardID })?.qr
            let reference = try await mediaStore.write(data, existingReference: existing, extension: fileExtension)
            if let index = snapshot.cards.firstIndex(where: { $0.id == cardID }) {
                snapshot.cards[index].qr = reference
                persist()
                showToast("Receiving QR attached.")
                FeedbackCenter.success()
            }
        } catch {
            showToast("Could not save that image.")
            FeedbackCenter.warning()
        }
    }

    func saveEditorCard() {
        guard let editor else { return }
        let trimmed = editor.card.nick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showToast("Give it a name first.")
            FeedbackCenter.warning()
            return
        }
        var saved = editor.card
        saved.nick = trimmed
        if editor.isNew {
            snapshot.cards.append(saved)
            snapshot.activeId = saved.id
            synchronizeEndpoints()
            showToast("\(saved.nick) is in the deck.")
        } else if let index = snapshot.cards.firstIndex(where: { $0.id == saved.id }) {
            snapshot.cards[index] = saved
            showToast("Redesigned.")
        }
        self.editor = nil
        path.removeAll()
        selectedTab = .home
        persist()
        FeedbackCenter.success()
    }

    func requestDeleteEditorCard() {
        cardDeleteOpen = true
        FeedbackCenter.warning()
    }

    func deleteEditorCard() {
        guard let editor, !editor.isNew else { return }
        let id = editor.card.id
        snapshot.cards.removeAll { $0.id == id }
        snapshot.tx.removeAll { $0.cardId == id }
        snapshot.dismissedNotices.removeAll { $0 == "low:\(id)" }
        snapshot.activeId = snapshot.cards.first?.id ?? ""
        self.editor = nil
        cardDeleteOpen = false
        path.removeAll()
        synchronizeEndpoints()
        persist()
        showToast("Gone. The money went with it.")
        FeedbackCenter.destructive()
    }

    func openTransactionEditor(_ transactionID: String) {
        guard let transaction = snapshot.tx.first(where: { $0.id == transactionID }) else { return }
        transactionEditor = TransactionEditorDraft(
            transactionID: transactionID,
            amount: String(abs(transaction.amount)),
            category: transaction.cat,
            note: transaction.note.isEmpty ? transaction.merchant : transaction.note,
            receipt: transaction.receipt
        )
        FeedbackCenter.tap()
    }

    func saveTransactionEditor() {
        guard let draft = transactionEditor,
              let index = snapshot.tx.firstIndex(where: { $0.id == draft.transactionID }),
              let amount = Double(draft.amount), amount > 0 else {
            showToast("Put a number in first.")
            return
        }
        let original = snapshot.tx[index]
        let sign = original.amount < 0 ? -1.0 : 1.0
        let newAmount = sign * amount
        let delta = newAmount - original.amount
        if let cardIndex = snapshot.cards.firstIndex(where: { $0.id == original.cardId }) {
            guard snapshot.cards[cardIndex].bal + delta >= 0 else {
                showToast("That change would overdraw \(snapshot.cards[cardIndex].nick).")
                FeedbackCenter.warning()
                return
            }
            snapshot.cards[cardIndex].bal += delta
        }
        snapshot.tx[index].amount = newAmount
        snapshot.tx[index].cat = draft.category
        snapshot.tx[index].note = draft.note
        snapshot.tx[index].merchant = draft.note.trimmingCharacters(in: .whitespaces).isEmpty ? original.merchant : draft.note
        snapshot.tx[index].receipt = draft.receipt
        transactionEditor = nil
        persist()
        showToast("Updated.")
        FeedbackCenter.success()
    }

    func attachTransactionEditorReceipt(_ data: Data, fileExtension: String = "jpg") async {
        do {
            let reference = try await mediaStore.write(data, existingReference: transactionEditor?.receipt, extension: fileExtension)
            transactionEditor?.receipt = reference
            showToast("Receipt attached.")
            FeedbackCenter.success()
        } catch {
            showToast("Could not attach that photo.")
            FeedbackCenter.warning()
        }
    }

    func deleteTransaction(_ transactionID: String) {
        guard let transaction = snapshot.tx.first(where: { $0.id == transactionID }) else { return }
        if let cardIndex = snapshot.cards.firstIndex(where: { $0.id == transaction.cardId }) {
            snapshot.cards[cardIndex].bal -= transaction.amount
        }
        snapshot.tx.removeAll { $0.id == transactionID }
        transactionEditor = nil
        persist()
        showToast("Deleted. Balance adjusted.")
        FeedbackCenter.destructive()
    }

    func closeSuccess() {
        success = nil
        amountDraft = ""
        selectedTab = .home
        FeedbackCenter.closed()
    }

    func renameUser(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        snapshot.userName = trimmed
        persist()
        FeedbackCenter.success()
    }

    func attachUserPhoto(_ data: Data) async {
        do {
            let ref = try await mediaStore.write(data, extension: "jpg")
            await MainActor.run {
                snapshot.userPhotoSrc = ref
                persist()
                FeedbackCenter.success()
            }
        } catch {
            await MainActor.run {
                showToast("Failed to save photo")
                FeedbackCenter.warning()
            }
        }
    }

    func toggleDailyReminder() async {
        let requested = !snapshot.nudgeDailyLog
        let accepted = await ReminderService.shared.setDailyReminder(enabled: requested)
        if requested && !accepted {
            snapshot.nudgeDailyLog = false
            showToast("Notifications are off. Enable them in System Settings to use reminders.")
            FeedbackCenter.warning()
        } else {
            snapshot.nudgeDailyLog = requested
            showToast(requested ? "Reminder set for 9pm." : "Daily reminder off.")
            FeedbackCenter.toggle(on: requested)
        }
        persist()
    }

    func toggleHaptics() {
        snapshot.haptics.toggle()
        FeedbackCenter.configure(haptics: snapshot.haptics, sounds: snapshot.sfx)
        persist()
        if snapshot.haptics { FeedbackCenter.success() }
        showToast(snapshot.haptics ? "Haptics on." : "Haptics off.")
    }

    func toggleSoundEffects() {
        snapshot.sfx.toggle()
        FeedbackCenter.configure(haptics: snapshot.haptics, sounds: snapshot.sfx)
        persist()
        if snapshot.sfx { FeedbackCenter.previewSoundEnabled() }
        showToast(snapshot.sfx ? "Sound effects on." : "Sound effects off.")
    }

    func dismissNotice(cardID: String) {
        let id = "low:\(cardID)"
        if !snapshot.dismissedNotices.contains(id) { snapshot.dismissedNotices.append(id) }
        persist()
        FeedbackCenter.tap()
    }

    func resetEverything() async {
        do { try await repository?.erase() } catch {}
        snapshot = .empty
        FeedbackCenter.configure(haptics: true, sounds: true)
        onboarding = OnboardingDraft()
        path.removeAll()
        selectedTab = .home
        editor = nil
        transactionEditor = nil
        eraseOpen = false
        synchronizeEndpoints()
        WidgetSnapshotPublisher.publish(snapshot)
        FeedbackCenter.destructive()
    }

    func backupData() async throws -> Data {
        try await BackupCodec.export(snapshot, media: mediaStore)
    }

    func csvData() -> Data {
        Data(("\u{feff}" + WalletMetrics.csv(transactions: snapshot.tx, cards: snapshot.cards, events: snapshot.events)).utf8)
    }

    func guessCategory() -> CategoryName? {
        let text = noteDraft.lowercased()
        let guesses: [(CategoryName, [String])] = [
            (.food, ["jollibee", "mcdo", "coffee", "lunch", "dinner"]),
            (.transport, ["grab", "angkas", "jeep", "bus", "fuel", "gas"]),
            (.bills, ["meralco", "water", "internet", "rent"]),
            (.groceries, ["grocery", "supermarket", "puregold", "sm market"]),
            (.shopping, ["shopee", "lazada", "mall"]),
            (.load, ["load", "globe", "smart"]),
            (.health, ["doctor", "medicine", "pharmacy"]),
            (.fun, ["movie", "game", "netflix"]),
        ]
        return guesses.first { _, words in words.contains { text.contains($0) } }?.0
    }

    @discardableResult
    /// Replaces the whole wallet — from a backup file or from the cloud — and resets the
    /// navigation around it, so nothing on screen still points at the old wallet.
    func apply(_ restored: WalletSnapshot) {
        var restored = restored
        // Cloud-only stamps never live in the local wallet; see `WalletSnapshot.savedAt`.
        restored.savedAt = nil
        restored.savedOn = nil
        restored.onboarded = restored.onboarded || !restored.cards.isEmpty
        snapshot = restored
        onboarding = OnboardingDraft()
        path.removeAll()
        editor = nil
        transactionEditor = nil
        selectedTab = .home
        synchronizeEndpoints()
        persist()
        WidgetSnapshotPublisher.publish(snapshot)
        FeedbackCenter.configure(haptics: snapshot.haptics, sounds: snapshot.sfx)
    }

    func restoreBackup(_ data: Data) async -> Bool {
        do {
            let restored = try await BackupCodec.restore(data, media: mediaStore)
            try await repository?.save(restored)
            apply(restored)
            showToast("Backup restored.")
            FeedbackCenter.success()
            return true
        } catch {
            showToast(error.localizedDescription)
            FeedbackCenter.warning()
            return false
        }
    }

    // MARK: - People

    /// Clears who the spend is split with. Deliberately leaves `sheetEventID` alone: saying
    /// "it was just me" is a statement about the people, not about which trip the spend
    /// belongs to, and dropping the event with them silently untagged the row.
    func clearSplitPeople() {
        splitWith = []
        splitMode = .even
        splitShares = [:]
        splitExact = [:]
    }

    /// The full reset, for opening or finishing a sheet — the event goes too.
    func clearSplitDraft() {
        clearSplitPeople()
        sheetEventID = nil
    }

    @discardableResult
    func addPerson(_ rawName: String, handle: String? = nil) -> String? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        // Adding a name that is already there selects it instead of making a duplicate, which
        // is what the user meant and stops two "Migo"s owing separate halves of the same bill.
        if let existing = snapshot.people.first(where: { $0.name.lowercased() == name.lowercased() }) {
            if let i = snapshot.people.firstIndex(where: { $0.id == existing.id }) {
                snapshot.people[i].archived = false
            }
            if !splitWith.contains(existing.id) { splitWith.append(existing.id) }
            persist()
            return existing.id
        }

        let person = Person(
            id: "person_\(UUID().uuidString.lowercased())",
            name: name,
            color: SplitMath.nextColor(existing: snapshot.people),
            handle: handle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        snapshot.people.append(person)
        // Someone added from inside the sheet is there to be split with — select them.
        if sheet != nil { splitWith.append(person.id) }
        persist()
        FeedbackCenter.selectionChanged()
        return person.id
    }

    func updatePerson(_ id: String, newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let i = snapshot.people.firstIndex(where: { $0.id == id }) else { return }
        
        let oldName = snapshot.people[i].name
        guard oldName != name else { return }
        
        snapshot.people[i].name = name
        
        // Retroactively update history
        for txIndex in snapshot.tx.indices {
            if snapshot.tx[txIndex].split != nil {
                for partIndex in snapshot.tx[txIndex].split!.parts.indices {
                    if snapshot.tx[txIndex].split!.parts[partIndex].personId == id {
                        snapshot.tx[txIndex].split!.parts[partIndex].name = name
                    }
                }
            }
        }
        
        persist()
        FeedbackCenter.success()
    }

    func attachPersonPhoto(personId: String, data: Data) async {
        do {
            let ref = try await mediaStore.write(data, extension: "jpg")
            await MainActor.run {
                guard let i = snapshot.people.firstIndex(where: { $0.id == personId }) else { return }
                snapshot.people[i].photoSrc = ref
                persist()
                FeedbackCenter.success()
            }
        } catch {
            await MainActor.run {
                showToast("Failed to save photo")
                FeedbackCenter.warning()
            }
        }
    }


    func deletePerson(_ id: String) {
        guard let person = snapshot.people.first(where: { $0.id == id }) else { return }
        // History is not rewritten: every split part carries its own name snapshot, so past
        // spends keep reading correctly after the person is gone.
        snapshot.people.removeAll { $0.id == id }
        splitWith.removeAll { $0 == id }
        for i in snapshot.events.indices {
            snapshot.events[i].memberIds.removeAll { $0 == id }
        }
        persist()
        showToast("\(person.name) removed. Their history stays.")
    }

    // MARK: - Split draft

    func toggleSplitPerson(_ id: String) {
        if let i = splitWith.firstIndex(of: id) { splitWith.remove(at: i) } else { splitWith.append(id) }
        FeedbackCenter.selectionChanged()
    }

    func setSplitShare(_ id: String, _ shares: Int) {
        splitShares[id] = max(0, shares)
    }

    // MARK: - Settling up

    /// Getting paid back is real money arriving, not a bookkeeping entry — this is the thing a
    /// shared-ledger app structurally cannot do. It tops up an actual card, and the top-up
    /// carries `repaysTxId` so a repayment is never mistaken for new income.
    ///
    /// One settlement can cover several spends at once, because that is how people actually pay
    /// each other back: one transfer for the whole night, not one per dish. Every part it covers
    /// points at the same settlement id, so undoing it reverses the lot as a unit.
    /// Opens the slide-to-confirm. An empty `transactionID` means everything they owe.
    func askSettle(personID: String, transactionID: String = "") {
        pendingSettle = PendingSettle(personID: personID, txID: transactionID)
        FeedbackCenter.opened()
    }

    func cancelSettle() {
        pendingSettle = nil
        FeedbackCenter.closed()
    }

    func settle(personID: String, transactionID: String? = nil, into cardID: String? = nil) {
        pendingSettle = nil
        let covered = snapshot.tx.filter { transaction in
            (transactionID == nil || transaction.id == transactionID) &&
            (transaction.split?.parts.contains { $0.personId == personID && $0.settledAt == nil } ?? false)
        }
        guard !covered.isEmpty else { return }

        let total = SplitMath.centavos(covered.reduce(0) { sum, transaction in
            sum + (transaction.split?.parts.first { $0.personId == personID }?.amount ?? 0)
        })
        guard total > 0 else { return }

        let name = covered[0].split?.parts.first { $0.personId == personID }?.name ?? "They"
        let targetID = cardID ?? covered[0].cardId
        guard let cardIndex = snapshot.cards.firstIndex(where: { $0.id == targetID }) else {
            showToast("Pick a card for it to land in.")
            return
        }
        let card = snapshot.cards[cardIndex]
        let settlementID = "tx_\(UUID().uuidString.lowercased())"
        let at = Date().timeIntervalSince1970 * 1000
        let ids = Set(covered.map(\.id))

        snapshot.cards[cardIndex].bal += total
        for i in snapshot.tx.indices where ids.contains(snapshot.tx[i].id) {
            guard var split = snapshot.tx[i].split else { continue }
            for j in split.parts.indices where split.parts[j].personId == personID && split.parts[j].settledAt == nil {
                split.parts[j].settledAt = at
                split.parts[j].settledTxId = settlementID
            }
            snapshot.tx[i].split = split
        }
        snapshot.tx.insert(Transaction(
            id: settlementID,
            cardId: card.id,
            merchant: "\(name) paid you back",
            cat: covered[0].cat,
            amount: total,
            at: at,
            note: covered.count == 1 ? covered[0].merchant : "\(covered.count) spends together",
            eventId: covered[0].eventId,
            repaysTxId: covered[0].id
        ), at: 0)

        success = SuccessState(
            kind: .funded,
            head: "Settled.",
            body: "₱\(MoneyFormat.amount(total)) from \(name) landed in \(card.nick). That is one fewer awkward message."
        )
        persist()
        FeedbackCenter.moneyIn()
    }

    /// Reverses a whole settlement: the top-up goes, and every part it covered reopens.
    func unsettle(settlementID: String) {
        guard let settlement = snapshot.tx.first(where: { $0.id == settlementID }),
              settlement.repaysTxId != nil,
              let cardIndex = snapshot.cards.firstIndex(where: { $0.id == settlement.cardId }) else { return }

        snapshot.cards[cardIndex].bal -= settlement.amount
        for i in snapshot.tx.indices {
            guard var split = snapshot.tx[i].split else { continue }
            var touched = false
            for j in split.parts.indices where split.parts[j].settledTxId == settlementID {
                split.parts[j].settledAt = nil
                split.parts[j].settledTxId = nil
                touched = true
            }
            if touched { snapshot.tx[i].split = split }
        }
        snapshot.tx.removeAll { $0.id == settlementID }
        persist()
        showToast("Undone. That ₱\(MoneyFormat.amount(settlement.amount)) is owed again.")
    }

    // MARK: - Events

    @discardableResult
    func createEvent(_ rawName: String, emoji: String = "📍") -> String? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showToast("Give the event a name first.")
            return nil
        }
        let event = EventGroup(
            id: "event_\(UUID().uuidString.lowercased())",
            name: name,
            emoji: emoji.isEmpty ? "📍" : emoji,
            startedAt: Date().timeIntervalSince1970 * 1000,
            endedAt: nil,
            // Whoever is selected in the sheet right now is who this trip is with.
            memberIds: splitWith
        )
        snapshot.events.insert(event, at: 0)
        sheetEventID = event.id
        persist()
        showToast("\(event.name) started. Spends will land in it.")
        return event.id
    }

    func closeEvent(_ id: String) {
        guard let i = snapshot.events.firstIndex(where: { $0.id == id }) else { return }
        snapshot.events[i].endedAt = Date().timeIntervalSince1970 * 1000
        if sheetEventID == id { sheetEventID = nil }
        persist()
        showToast("\(snapshot.events[i].name) closed. Nothing new lands in it.")
    }

    func reopenEvent(_ id: String) {
        guard let i = snapshot.events.firstIndex(where: { $0.id == id }) else { return }
        snapshot.events[i].endedAt = nil
        persist()
    }

    func deleteEvent(_ id: String) {
        guard let event = snapshot.events.first(where: { $0.id == id }) else { return }
        // Only the grouping goes. The spends are real money and stay in the wallet — dropping
        // them with the event would silently change the user's balances.
        snapshot.events.removeAll { $0.id == id }
        for i in snapshot.tx.indices where snapshot.tx[i].eventId == id {
            snapshot.tx[i].eventId = nil
        }
        if sheetEventID == id { sheetEventID = nil }
        if openEventID == id { openEventID = nil }
        if !path.isEmpty { path.removeLast() }
        persist()
        showToast("\(event.name) removed. The spends stayed.")
    }

    func openEventDetail(_ id: String) {
        openEventID = id
        path.append(.event(id))
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func persist() {
        WidgetSnapshotPublisher.publish(snapshot)
        guard let repository else { return }
        let value = snapshot
        Task {
            do { try await repository.save(value) }
            catch { showToast("Could not save this change on your device.") }
        }
    }

    func setAppTheme(_ theme: AppTheme) {
        snapshot.appTheme = theme
        persist()
    }

    private func synchronizeEndpoints() {
        let first = snapshot.cards.first?.id ?? ""
        if !snapshot.cards.contains(where: { $0.id == snapshot.activeId }) { snapshot.activeId = first }
        if !snapshot.cards.contains(where: { $0.id == transferFromID }) { transferFromID = snapshot.activeId }
        if !snapshot.cards.contains(where: { $0.id == transferToID }) || transferToID == transferFromID {
            transferToID = snapshot.cards.first { $0.id != transferFromID }?.id ?? ""
        }
        if !snapshot.cards.contains(where: { $0.id == moveToCardID }) || moveToCardID == sheetCardID {
            moveToCardID = snapshot.cards.first { $0.id != sheetCardID }?.id ?? ""
        }
        if !snapshot.cards.contains(where: { $0.id == sheetCardID }) { sheetCardID = snapshot.activeId }
    }
}
