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
    var qrViewerCardID: String?
    var receiptViewerTransactionID: String?
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
        let launchArguments = ProcessInfo.processInfo.arguments
#if DEBUG
        if launchArguments.contains("--demo-wallet") {
            try? await repository.erase()
            snapshot = launchArguments.contains("--showcase") ? .simulatorShowcase : .simulatorDemo
            if launchArguments.contains("--empty-activity") { snapshot.tx = [] }
            if launchArguments.contains("--layout=stack") { snapshot.homeLayout = .stack }
            if launchArguments.contains("--tab=insights") { selectedTab = .insights }
            if launchArguments.contains("--tab=search") { selectedTab = .search }
            if launchArguments.contains("--tab=settings") { selectedTab = .settings }
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
#endif
        if launchArguments.contains("--reset-wallet") {
            try? await repository.erase()
        }
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
            receiptDraft = try await mediaStore.write(data, extension: fileExtension)
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
                kind: .moved,
                head: "Moved.",
                body: "₱\(MoneyFormat.amount(typedAmount)) from \(card.nick) to \(destination.nick). No fees, because no bank was involved."
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
        snapshot.cards[cardIndex].bal += sign * typedAmount
        let transaction = Transaction(
            id: "tx_\(UUID().uuidString.lowercased())",
            cardId: card.id,
            merchant: noteDraft.isEmpty ? (kind == .deposit ? "Top up" : categoryDraft.rawValue) : noteDraft,
            cat: categoryDraft,
            amount: sign * typedAmount,
            at: Date().timeIntervalSince1970 * 1000,
            note: noteDraft,
            receipt: receiptDraft
        )
        snapshot.tx.insert(transaction, at: 0)
        sheet = nil
        receiptDraft = nil
        success = SuccessState(
            kind: kind == .deposit ? .funded : .logged,
            head: kind == .deposit ? "Funded." : "Logged it.",
            body: kind == .deposit
                ? "₱\(MoneyFormat.amount(typedAmount)) added to \(card.nick). Look at you, being responsible."
                : "₱\(MoneyFormat.amount(typedAmount)) off \(card.nick). That took four seconds."
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
            head: "Moved.",
            body: "₱\(MoneyFormat.amount(amount)) from \(source.nick) to \(destination.nick). No fees, because no bank was involved."
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
            let reference = try await mediaStore.write(data, extension: fileExtension)
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
            let reference = try await mediaStore.write(data, extension: fileExtension)
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

    func toggleLowBalanceNudge() {
        snapshot.nudgeLowBalance.toggle()
        persist()
        FeedbackCenter.toggle(on: snapshot.nudgeLowBalance)
        showToast(snapshot.nudgeLowBalance ? "Low balance nudges on." : "Low balance nudges off.")
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
        Data(("\u{feff}" + WalletMetrics.csv(transactions: snapshot.tx, cards: snapshot.cards)).utf8)
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
    func restoreBackup(_ data: Data) async -> Bool {
        do {
            let restored = try await BackupCodec.restore(data, media: mediaStore)
            try await repository?.save(restored)
            snapshot = restored
            onboarding = OnboardingDraft()
            path.removeAll()
            editor = nil
            transactionEditor = nil
            selectedTab = .home
            synchronizeEndpoints()
            WidgetSnapshotPublisher.publish(snapshot)
            FeedbackCenter.configure(haptics: snapshot.haptics, sounds: snapshot.sfx)
            showToast("Backup restored.")
            FeedbackCenter.success()
            return true
        } catch {
            showToast(error.localizedDescription)
            FeedbackCenter.warning()
            return false
        }
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
