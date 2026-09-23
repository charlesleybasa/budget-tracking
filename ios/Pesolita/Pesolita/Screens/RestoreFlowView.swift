import SwiftUI

/// Bringing a Pesolita Pro wallet back with Google — every case in one sheet.
///
/// The sheet does not decide anything itself: `SyncManager` reads the cloud and lands in a
/// phase, and this view describes that phase and offers the choices it allows. Nothing that
/// loses data happens without the user reading exactly what will be lost.
struct RestoreFlowView: View {
    @Bindable var store: WalletStore
    @EnvironmentObject private var sync: SyncManager
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    /// Show the Google / backup-file choice first, or go straight to Google.
    var startsWithChoice: Bool

    @State private var signingIn = false
    @State private var signInError: String?
    @State private var working = false
    /// Set once the user commits to an outcome, so the sheet can finish with what happened.
    @State private var outcome: Outcome?
    @State private var choice: TwoWalletChoice = .combine
    @State private var confirmingDestructive = false
    @State private var importingFile = false

    private enum Outcome: Equatable {
        case restored(cards: Int, entries: Int)
        case combined(cards: Int, entries: Int)
        case keptPhone
        case fresh
    }

    private enum TwoWalletChoice { case combine, useBackup, keepPhone }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Capsule().fill(Tokens.fillStrong).frame(width: 38, height: 4).padding(.top, 10)
                content
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                    .animation(Tokens.easeOut(0.28), value: stateKey)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Tokens.bgBase)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(working || signingIn)
        .task {
            if !startsWithChoice && !sync.isAuthenticated { await signIn() }
        }
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            Task {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), await store.restoreBackup(data) { dismiss() }
            }
        }
    }

    /// A value that changes whenever the visible state does, for the cross-fade.
    private var stateKey: String { "\(outcome.map { "\($0)" } ?? "")|\(sync.phase)|\(signingIn)" }

    // MARK: - State machine → screen

    @ViewBuilder
    private var content: some View {
        if let outcome {
            done(outcome)
        } else if signingIn {
            waiting(title: "Opening Google…", body: "Sign in with the Google account you used for Pesolita Pro.")
        } else if let signInError {
            problem(title: "Google sign-in didn't finish", body: signInError, retry: "Try again") { await signIn() }
        } else if !sync.isAuthenticated {
            welcome
        } else {
            switch sync.phase {
            case .signedOut, .reconciling:
                waiting(title: "Finding your wallet…", body: "Checking the backup for \(sync.email ?? "your account").")
            case .needsDecision(let decision):
                decide(decision)
            case .live:
                allSet
            case .paused(.notPro):
                notPro
            case .paused(.unreachable):
                problem(title: "Couldn't reach your backup",
                        body: "Nothing was changed on this iPhone or in your backup. Check your connection and try again.",
                        retry: "Try again") { await sync.retry(store) }
            }
        }
    }

    // MARK: - Welcome back

    private var welcome: some View {
        VStack(spacing: 0) {
            SpriteAnimationView(spec: .peekaboo, size: 150)
            title("Welcome back")
            lede("Bring your wallet back from your Pesolita Pro backup, or from a backup file you saved.")
                .padding(.top, 8)

            VStack(spacing: 10) {
                GoogleButton { Task { await signIn() } }
                Button { importingFile = true } label: {
                    Label("Use a backup file", systemImage: "doc")
                        .font(AppFont.outfit(15, weight: .semibold))
                        .foregroundStyle(Tokens.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Tokens.fill, in: Capsule())
                }
                .buttonStyle(PesolitaPressStyle())
            }
            .padding(.top, 26)

            footnote("Signing in only reads your backup. Nothing on this iPhone changes until you choose.")
                .padding(.top, 14)
        }
    }

    // MARK: - Decisions

    @ViewBuilder
    private func decide(_ decision: SyncDecision) -> some View {
        switch decision {
        case .restore(let summary): found(summary)
        case .twoWallets(let summary): twoWallets(summary)
        case .nothingYet: noBackup
        case .uploadLocal, .adoptCloud, .inStep: waiting(title: "Finishing up…", body: "")
        }
    }

    private func found(_ summary: CloudSummary) -> some View {
        VStack(spacing: 0) {
            SpriteAnimationView(spec: .flyingIdle, size: 140)
            title("Found your wallet")
            lede("Your backup on \(sync.email ?? "Google") is ready to come back to this iPhone.")
                .padding(.top, 8)
            BackupSummaryCard(label: "YOUR BACKUP", cards: summary.cards, entries: summary.transactions,
                              detail: savedLine(summary), names: summary.cardNames, emphasised: true)
                .padding(.top, 20)
            primary("Restore my wallet") {
                await sync.useBackup(store)
                outcome = .restored(cards: summary.cards, entries: summary.transactions)
            }
            .padding(.top, 20)
            secondary("Start fresh instead") {
                sync.startFresh()
                outcome = .fresh
            }
            footnote("Starting fresh keeps your backup untouched in the cloud.")
                .padding(.top, 4)
        }
    }

    private func twoWallets(_ summary: CloudSummary) -> some View {
        let cloud = sync.cloudSnapshot ?? .empty
        let preview = MergePreview(local: store.snapshot, cloud: cloud)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                title("You have two wallets")
                lede("This iPhone has a wallet, and so does your backup. Choose how to bring them together.")
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)

            // Equal heights, top-aligned: the two wallets are being compared, so they have to
            // line up — the backup's longer "saved" line otherwise knocked them out of step.
            HStack(alignment: .top, spacing: 10) {
                BackupSummaryCard(label: "THIS IPHONE", cards: store.snapshot.cards.count,
                                  entries: store.snapshot.tx.count, detail: "Now", names: [], emphasised: false)
                BackupSummaryCard(label: "YOUR BACKUP", cards: summary.cards, entries: summary.transactions,
                                  detail: savedLine(summary), names: [], emphasised: false)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 20)

            VStack(spacing: 8) {
                optionRow(.combine, title: "Combine both", badge: "Recommended",
                          body: combineBody(preview), warning: clashWarning(preview))
                optionRow(.useBackup, title: "Use my backup",
                          body: "Replaces this iPhone's wallet. \(lossLine(cards: store.snapshot.cards.count, entries: store.snapshot.tx.count, from: "this iPhone"))",
                          warning: nil)
                optionRow(.keepPhone, title: storeManager.hasPro ? "Keep this iPhone's wallet" : "Keep this iPhone's wallet, don't restore",
                          body: storeManager.hasPro
                            ? "Replaces your backup. \(lossLine(cards: summary.cards, entries: summary.transactions, from: "your backup"))"
                            : "Your backup stays in the cloud, untouched.",
                          warning: nil)
            }
            .padding(.top, 18)

            primary(choice == .combine ? "Combine wallets" : "Continue") {
                if choice == .combine {
                    await sync.combine(store)
                    outcome = .combined(cards: store.snapshot.cards.count, entries: store.snapshot.tx.count)
                } else {
                    confirmingDestructive = true
                }
            }
            .padding(.top, 20)
        }
        .alert(choice == .useBackup ? "Replace this iPhone's wallet?" : "Replace your backup?",
               isPresented: $confirmingDestructive) {
            Button("Cancel", role: .cancel) {}
            Button(choice == .useBackup ? "Replace this iPhone" : "Replace backup", role: .destructive) {
                Task {
                    working = true
                    defer { working = false }
                    if choice == .useBackup {
                        await sync.useBackup(store)
                        outcome = .restored(cards: summary.cards, entries: summary.transactions)
                    } else {
                        await sync.keepThisPhone(store)
                        outcome = .keptPhone
                    }
                }
            }
        } message: {
            Text(choice == .useBackup
                 ? "\(lossLine(cards: store.snapshot.cards.count, entries: store.snapshot.tx.count, from: "this iPhone")) Combine keeps them instead."
                 : "\(lossLine(cards: summary.cards, entries: summary.transactions, from: "your backup")) Combine keeps them instead.")
        }
    }

    private var noBackup: some View {
        VStack(spacing: 0) {
            SpriteAnimationView(spec: .idleSteady, size: 130)
            title("No backup here yet")
            lede("\(sync.email ?? "This Google account") doesn't have a Pesolita backup. If you used a different account before, switch to it.")
                .padding(.top, 8)
            primary(storeManager.hasPro ? "Start backing up here" : "Continue") {
                sync.startFresh()
                outcome = .fresh
            }
            .padding(.top, 22)
            secondary("Use another Google account") {
                await sync.signOut()
                await signIn()
            }
        }
    }

    // MARK: - Pro

    private var notPro: some View {
        VStack(spacing: 0) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Tokens.accentText)
                .frame(width: 84, height: 84)
                .background(Tokens.accentTint, in: Circle())
            title("Backups are part of Pro")
                .padding(.top, 14)
            lede("You're signed in as \(sync.email ?? "your Google account"), but this Apple ID doesn't have Pesolita Pro, so this iPhone won't back up.")
                .padding(.top, 8)
            ProPurchaseButton()
                .padding(.top, 22)
            RestorePurchasesButton()
            secondary("Not now") { dismiss() }
        }
    }

    // MARK: - Done

    private var allSet: some View {
        VStack(spacing: 0) {
            SpriteAnimationView(spec: .celebrate, size: 150)
            title("You're backed up")
            lede("\(sync.email ?? "Your account") keeps a copy of this wallet. Changes back up on their own.")
                .padding(.top, 8)
            primary("Done") { dismiss() }
                .padding(.top, 22)
        }
    }

    private func done(_ outcome: Outcome) -> some View {
        let (head, body): (String, String) = {
            switch outcome {
            case .restored(let cards, let entries):
                return ("Welcome back", "\(plural(cards, "card")) and \(plural(entries, "entry", "entries")) are back on this iPhone.")
            case .combined(let cards, let entries):
                return ("Wallets combined", "You now have \(plural(cards, "card")) and \(plural(entries, "entry", "entries")). Nothing was left behind.")
            case .keptPhone:
                return ("Backup updated", "Your backup now matches this iPhone.")
            case .fresh:
                return ("All set", storeManager.hasPro ? "This wallet backs up to \(sync.email ?? "Google") from now on." : "Your backup is untouched in the cloud.")
            }
        }()
        return VStack(spacing: 0) {
            SpriteAnimationView(spec: .celebrate, size: 150)
            title(head)
            lede(body).padding(.top, 8)
            if !storeManager.hasPro, outcome != .fresh {
                // Restoring was free; keeping it safe from here is Pro.
                VStack(spacing: 10) {
                    Text("Keep it backed up")
                        .font(AppFont.outfit(13, weight: .bold))
                        .foregroundStyle(Tokens.textPrimary)
                    Text("New spends stay on this iPhone only until Pesolita Pro is on.")
                        .font(AppFont.outfit(12.5))
                        .foregroundStyle(Tokens.textSecondary)
                        .multilineTextAlignment(.center)
                    ProPurchaseButton()
                    RestorePurchasesButton()
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Tokens.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 20)
            }
            primary("Done") { dismiss() }
                .padding(.top, 18)
        }
    }

    // MARK: - Shared pieces

    private func waiting(title text: String, body: String) -> some View {
        VStack(spacing: 0) {
            SpriteAnimationView(spec: .flyingIdle, size: 140)
            title(text)
            if !body.isEmpty { lede(body).padding(.top, 8) }
            ProgressView().tint(Tokens.textSecondary).padding(.top, 18)
        }
        .frame(minHeight: 360)
    }

    private func problem(title text: String, body: String, retry label: String, action: @escaping () async -> Void) -> some View {
        VStack(spacing: 0) {
            SpriteAnimationView(spec: .sad, size: 130)
            title(text)
            lede(body).padding(.top, 8)
            primary(label, action: action).padding(.top, 22)
            secondary("Close") { dismiss() }
        }
    }

    private func optionRow(_ value: TwoWalletChoice, title text: String, badge: String? = nil,
                           body: String, warning: String?) -> some View {
        let selected = choice == value
        return Button {
            choice = value
            FeedbackCenter.selectionChanged()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Tokens.textPrimary : Tokens.textTertiary)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(text)
                            .font(AppFont.outfit(15, weight: .bold))
                            .foregroundStyle(Tokens.textPrimary)
                        if let badge {
                            Text(badge.uppercased())
                                .font(AppFont.outfit(9, weight: .bold))
                                .kerning(0.6)
                                .foregroundStyle(Tokens.onAccent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Tokens.accent, in: Capsule())
                        }
                    }
                    Text(body)
                        .font(AppFont.outfit(12.5))
                        .foregroundStyle(Tokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let warning {
                        Label(warning, systemImage: "exclamationmark.circle")
                            .font(AppFont.outfit(12, weight: .medium))
                            .foregroundStyle(Tokens.accentText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Tokens.fillRaised : Tokens.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Tokens.textPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(AppFont.outfit(26, weight: .bold, relativeTo: .title2))
            .foregroundStyle(Tokens.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.top, 6)
    }

    private func lede(_ text: String) -> some View {
        Text(text)
            .font(AppFont.outfit(14.5, relativeTo: .body))
            .foregroundStyle(Tokens.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: 330)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(AppFont.outfit(12, relativeTo: .caption))
            .foregroundStyle(Tokens.textCaption)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
    }

    private func primary(_ label: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                working = true
                defer { working = false }
                await action()
            }
        } label: {
            ZStack {
                Text(label).opacity(working ? 0 : 1)
                if working { ProgressView().tint(Tokens.bgBase) }
            }
            .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
            .foregroundStyle(Tokens.bgBase)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Tokens.textPrimary, in: Capsule())
        }
        .buttonStyle(PesolitaPressStyle())
        .disabled(working)
    }

    private func secondary(_ label: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(label)
                .font(AppFont.outfit(14, weight: .semibold))
                .foregroundStyle(Tokens.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    private func signIn() async {
        signInError = nil
        signingIn = true
        defer { signingIn = false }
        do {
            try await sync.signInWithGoogle()
        } catch {
            // Closing Google's sheet is a choice, not an error worth a red screen.
            let text = error.localizedDescription.lowercased()
            if !(text.contains("cancel")) { signInError = error.localizedDescription }
        }
    }

    // MARK: - Copy

    private func savedLine(_ summary: CloudSummary) -> String {
        guard let savedAt = summary.savedAt else { return "Saved earlier" }
        let when = savedAt.formatted(.relative(presentation: .named))
        return summary.savedOn.map { "Saved \(when) on \($0)" } ?? "Saved \(when)"
    }

    private func combineBody(_ preview: MergePreview) -> String {
        var parts: [String] = []
        if !preview.cardsFromBackup.isEmpty || preview.transactionsFromBackup > 0 {
            parts.append("Adds \(plural(preview.cardsFromBackup.count, "card")) and \(plural(preview.transactionsFromBackup, "entry", "entries")) from your backup")
        }
        if !preview.cardsFromPhone.isEmpty || preview.transactionsFromPhone > 0 {
            parts.append("keeps \(plural(preview.cardsFromPhone.count, "card")) and \(plural(preview.transactionsFromPhone, "entry", "entries")) from this iPhone")
        }
        let sentence = parts.isEmpty ? "Keeps everything from both" : parts.joined(separator: ", ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + ". Nothing is doubled."
    }

    private func clashWarning(_ preview: MergePreview) -> String? {
        guard let first = preview.sameNamedCards.first else { return nil }
        return preview.sameNamedCards.count == 1
            ? "Both have a \u{201C}\(first)\u{201D} card. You'll see two — delete one after if they're the same."
            : "\(preview.sameNamedCards.count) cards share a name on both sides. You'll see each twice — delete the extras after."
    }

    private func lossLine(cards: Int, entries: Int, from place: String) -> String {
        "\(plural(cards, "card")) and \(plural(entries, "entry", "entries")) on \(place) will be removed."
    }

    private func plural(_ count: Int, _ one: String, _ many: String? = nil) -> String {
        "\(count) \(count == 1 ? one : (many ?? one + "s"))"
    }
}

// MARK: - Components

/// A compact description of one wallet — on this iPhone or in the backup.
struct BackupSummaryCard: View {
    let label: String
    let cards: Int
    let entries: Int
    let detail: String
    let names: [String]
    let emphasised: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.outfit(10, weight: .bold))
                .kerning(1.1)
                .foregroundStyle(Tokens.textCaption)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(cards)")
                    .font(AppFont.outfit(emphasised ? 30 : 24, weight: .bold))
                    .foregroundStyle(Tokens.textPrimary)
                    .monospacedDigit()
                Text(cards == 1 ? "card" : "cards")
                    .font(AppFont.outfit(13, weight: .medium))
                    .foregroundStyle(Tokens.textSecondary)
            }
            Text("\(entries) \(entries == 1 ? "entry" : "entries")")
                .font(AppFont.outfit(13, weight: .semibold))
                .foregroundStyle(Tokens.textPrimary)
            Text(detail)
                .font(AppFont.outfit(11.5))
                .foregroundStyle(Tokens.textCaption)
                .lineLimit(2)
            if !names.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(names.prefix(6).enumerated()), id: \.offset) { _, name in
                        Text(name)
                            .font(AppFont.outfit(11.5, weight: .semibold))
                            .foregroundStyle(Tokens.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Tokens.fillRaised, in: Capsule())
                    }
                    if names.count > 6 {
                        Text("+\(names.count - 6) more")
                            .font(AppFont.outfit(11.5, weight: .semibold))
                            .foregroundStyle(Tokens.textSecondary)
                            .padding(.vertical, 5)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tokens.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// "Continue with Google", laid out per Google's sign-in branding: neutral fill, the Google
/// mark on the left, that exact label. Drop the official mark into the asset catalog as
/// `google-g` and it is used automatically; until then a neutral glyph stands in.
struct GoogleButton: View {
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if UIImage(named: "google-g") != nil {
                        Image("google-g").resizable().scaledToFit()
                    } else {
                        Image(systemName: "g.circle.fill").resizable().scaledToFit()
                            .foregroundStyle(scheme == .dark ? .white : Color(hex: "#1F1F1F"))
                    }
                }
                .frame(width: 20, height: 20)
                Text("Continue with Google")
                    .font(AppFont.outfit(16, weight: .semibold, relativeTo: .body))
            }
            .foregroundStyle(scheme == .dark ? Color(hex: "#E3E3E3") : Color(hex: "#1F1F1F"))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(scheme == .dark ? Color(hex: "#131314") : .white, in: Capsule())
            .overlay(Capsule().strokeBorder(scheme == .dark ? Color(hex: "#8E918F") : Color(hex: "#747775"), lineWidth: 1))
        }
        .buttonStyle(PesolitaPressStyle())
    }
}

/// Buys Pesolita Pro through the App Store — the real purchase, with the App Store's price.
struct ProPurchaseButton: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var buying = false
    @State private var failed: String?

    var body: some View {
        VStack(spacing: 6) {
            if storeManager.productsUnavailable {
                Button { Task { await storeManager.loadProducts() } } label: {
                    Label("The App Store didn't answer — try again", systemImage: "arrow.clockwise")
                        .font(AppFont.outfit(14.5, weight: .semibold))
                        .foregroundStyle(Tokens.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Tokens.fill, in: Capsule())
                }
                .buttonStyle(PesolitaPressStyle())
            } else {
            Button {
                guard let product = storeManager.products.first(where: { $0.id == storeManager.proProductID }) else { return }
                Task {
                    buying = true
                    defer { buying = false }
                    do { try await storeManager.purchase(product) } catch { failed = error.localizedDescription }
                }
            } label: {
                ZStack {
                    if buying || storeManager.products.isEmpty {
                        ProgressView().tint(Tokens.onAccent)
                    } else {
                        Text("Get Pesolita Pro — \(storeManager.products.first?.displayPrice ?? "") once")
                    }
                }
                .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
                .foregroundStyle(Tokens.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Tokens.accent, in: Capsule())
            }
            .buttonStyle(PesolitaPressStyle())
            .disabled(buying || storeManager.products.isEmpty)
            }
            if let failed {
                Text(failed).font(AppFont.outfit(12)).foregroundStyle(Tokens.negative).multilineTextAlignment(.center)
            }
        }
        .task { if storeManager.products.isEmpty { await storeManager.loadProducts() } }
    }
}

/// Required for a one-time purchase, and the way Pro follows an Apple ID onto a new iPhone.
struct RestorePurchasesButton: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var message: String?

    var body: some View {
        VStack(spacing: 4) {
            Button {
                Task {
                    let owned = await storeManager.restorePurchases()
                    message = owned ? "Pesolita Pro is on." : "No Pesolita Pro purchase on this Apple ID."
                }
            } label: {
                Text(storeManager.isRestoring ? "Checking…" : "Restore Purchases")
                    .font(AppFont.outfit(13.5, weight: .semibold))
                    .foregroundStyle(Tokens.link)
                    .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
            .disabled(storeManager.isRestoring)
            if let message {
                Text(message).font(AppFont.outfit(12)).foregroundStyle(Tokens.textSecondary)
            }
        }
    }
}
