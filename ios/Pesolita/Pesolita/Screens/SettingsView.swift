import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct SettingsView: View {
    @Bindable var store: WalletStore
    @State private var name = ""
    @State private var editingName = false
    @FocusState private var nameFocused: Bool
    @State private var exportDocument = PesolitaExportDocument()
    @State private var exportContentType: UTType = .json
    @State private var exportFilename = "pesolita-backup"
    @State private var exportSuccessMessage = "Saved."
    @State private var exportingFile = false
    @State private var importingBackup = false
    @State private var confirmingRestore = false
    @State private var pendingRestore: Data?
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showingProUpsell = false
    @State private var attachingPhotoToUser = false
    @State private var confirmingSignOut = false
    @State private var isMascotFloating = false

    var body: some View {
        ZStack {
            Tokens.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                List {
                        settingsGroup("Pesolita Pro") {
                            if store.isPro {
                                settingsRow(
                                    title: "Pesolita Pro Active",
                                    subtitle: "Lifetime Sync & Cloud Backup Enabled",
                                    symbol: "checkmark.seal.fill",
                                    tint: Tokens.green,
                                    iconBackground: Tokens.green.opacity(0.14),
                                    showMascot: true,
                                    showPriceBadge: false
                                ) { showingProUpsell = true }
                            } else {
                                settingsRow(
                                    title: "Upgrade to Pesolita Pro",
                                    subtitle: "Unlock Lifetime Sync & Cloud Backup",
                                    symbol: "sparkles",
                                    tint: Tokens.accentText,
                                    iconBackground: Tokens.accentTint,
                                    showMascot: true,
                                    showPriceBadge: true
                                ) { showingProUpsell = true }
                            }
                            
                            backupStatusRow

                            if syncManager.isAuthenticated {
                                settingsRow(
                                    title: "Sign out of Google",
                                    subtitle: "Your wallet stays on this iPhone",
                                    symbol: "rectangle.portrait.and.arrow.right",
                                    tint: Tokens.negative,
                                    iconBackground: Tokens.redTint,
                                    danger: true
                                ) { confirmingSignOut = true }
                            }

                            if !store.isPro {
                                settingsRow(
                                    title: "Restore Purchases",
                                    subtitle: "Bought Pro on another iPhone? Bring it here",
                                    symbol: "arrow.clockwise",
                                    tint: Tokens.link,
                                    iconBackground: Tokens.blueTint
                                ) { Task { await storeManager.restorePurchases() } }
                            }
                        }
                        settingsGroup("Money") {
                            settingsRow(
                                title: "Card limits",
                                subtitle: store.activeCard.map { "\($0.nick)" } ?? "Add a card first",
                                symbol: "chart.bar.fill",
                                tint: Tokens.accentText,
                                iconBackground: Tokens.accentTint
                            ) { _ = store.activeCard.map { store.showCardDetail($0.id) } }
                        }

                        settingsGroup("Splitting") {
                            settingsRow(
                                title: "People",
                                subtitle: store.totalOwed > 0
                                    ? "₱\(MoneyFormat.amount(store.totalOwed)) still out with \(store.snapshot.people.count == 1 ? "1 person" : "\(store.snapshot.people.count) people")"
                                    : (store.snapshot.people.isEmpty ? "Nobody added yet" : "Everyone is settled up"),
                                symbol: "person.2.fill",
                                tint: Tokens.green,
                                iconBackground: Tokens.green.opacity(0.14)
                            ) { store.path.append(.people) }

                            settingsRow(
                                title: "Events",
                                subtitle: store.snapshot.events.isEmpty
                                    ? "Group a trip or a night out"
                                    : (store.snapshot.events.count == 1 ? "1 event" : "\(store.snapshot.events.count) events"),
                                symbol: "mappin.and.ellipse",
                                tint: Tokens.violetText,
                                iconBackground: Tokens.violetTint
                            ) { store.path.append(.events) }
                        }

                        settingsGroup("Nudges") {
                            settingsRow(
                                title: "Daily log reminder",
                                subtitle: "A nudge at 9pm — needs notification permission",
                                symbol: "bell",
                                tint: Tokens.violetText,
                                iconBackground: Tokens.violetTint,
                                isOn: store.snapshot.nudgeDailyLog
                            ) { Task { await store.toggleDailyReminder() } }
                        }

                        settingsGroup("Feel") {
                            settingsRow(
                                title: "Haptics",
                                subtitle: "A short buzz on every tap and total",
                                symbol: "iphone.radiowaves.left.and.right",
                                tint: Tokens.blue,
                                iconBackground: Tokens.blue.opacity(0.12),
                                isOn: store.snapshot.haptics,
                                action: store.toggleHaptics
                            )
                            settingsRow(
                                title: "Sound effects",
                                subtitle: "Quiet tones for keys, money in and money out",
                                symbol: "speaker.wave.2",
                                tint: Tokens.green,
                                iconBackground: Tokens.green.opacity(0.12),
                                isOn: store.snapshot.sfx,
                                action: store.toggleSoundEffects
                            )
                        }

                        settingsGroup("Your data") {
                            settingsRow(
                                title: "Hide balances",
                                subtitle: "Blur every number across the app and widget",
                                symbol: "eye",
                                tint: Tokens.text,
                                iconBackground: Tokens.text.opacity(0.08),
                                isOn: store.snapshot.privacy,
                                action: store.togglePrivacy
                            )
                            settingsRow(
                                title: "Hide widget balances",
                                subtitle: "Blur numbers on your Home Screen widget only",
                                symbol: "eye.slash",
                                tint: Tokens.text,
                                iconBackground: Tokens.text.opacity(0.08),
                                isOn: store.snapshot.widgetPrivacy,
                                action: store.toggleWidgetPrivacy
                            )
                            settingsRow(title: "Back up wallet", subtitle: "Cards, history and settings as one file", symbol: "arrow.down", tint: Tokens.green, iconBackground: Tokens.green.opacity(0.12), identifier: "backup-wallet", action: exportBackup)
                            settingsRow(title: "Restore from backup", subtitle: "Replaces everything on this device", symbol: "arrow.up", tint: Tokens.blue, iconBackground: Tokens.blue.opacity(0.12), identifier: "restore-wallet") { importingBackup = true }
                                .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json, .data]) { result in
                                    Task { @MainActor in await prepareRestore(result) }
                                }
                            settingsRow(title: "Export CSV", subtitle: "Transactions only, for a spreadsheet", symbol: "doc.text", tint: Tokens.text, iconBackground: Tokens.text.opacity(0.08), action: exportCSV)
                            settingsRow(title: "Start over", subtitle: "Erase all cards and history from this device", symbol: "trash", tint: Tokens.redDeep, iconBackground: Tokens.red.opacity(0.12), danger: true) {
                                    store.eraseOpen = true
                                    FeedbackCenter.warning()
                                }
                        }
                        
                        settingsGroup("Sharing") {
                            Button(action: shareQRCodes) {
                                settingsRowLabel(
                                    title: "Share QR codes",
                                    subtitle: "Send all your card QR codes to apps like WhatsApp",
                                    symbol: "square.and.arrow.up",
                                    tint: Tokens.blue,
                                    iconBackground: Tokens.blue.opacity(0.12)
                                )
                            }
                        }

                        settingsGroup("Appearance") {
                            ThemeSwitcherView(selection: store.snapshot.appTheme) { store.setAppTheme($0) }
                        }

                        settingsGroup("About & help") {
                            VStack(spacing: 0) {
                                Link(destination: URL(string: "https://pesolita.vercel.app/privacy")!) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "hand.raised.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Tokens.link)
                                            .frame(width: 32, height: 32)
                                            .background(Tokens.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        Text("Privacy Policy")
                                            .font(AppFont.outfit(13.5, weight: .semibold, relativeTo: .subheadline))
                                            .foregroundStyle(Tokens.text)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Tokens.muted3)
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                
                                separator
                                
                                Link(destination: URL(string: "https://pesolita.vercel.app/support")!) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "questionmark.circle.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Tokens.positive)
                                            .frame(width: 32, height: 32)
                                            .background(Tokens.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        Text("Support")
                                            .font(AppFont.outfit(13.5, weight: .semibold, relativeTo: .subheadline))
                                            .foregroundStyle(Tokens.text)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Tokens.muted3)
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                            }
                        }

                        Text("Pesolita 1.0 · Data is stored on device unless you export it.")
                            .font(AppFont.outfit(11.5, relativeTo: .caption))
                            .foregroundStyle(Tokens.muted3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, 60)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            name = store.snapshot.userName
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isMascotFloating = true
            }
        }
        .fileExporter(isPresented: $exportingFile, document: exportDocument, contentType: exportContentType, defaultFilename: exportFilename) { exportFinished($0) }
        .alert("Restore this backup?", isPresented: $confirmingRestore) {
            Button("Keep current wallet", role: .cancel) { pendingRestore = nil }
            Button("Restore backup", role: .destructive) {
                guard let data = pendingRestore else { return }
                pendingRestore = nil
                Task { await store.restoreBackup(data) }
            }
        } message: {
            Text("Your current cards and activity will be replaced by the contents of this file.")
        }
        .alert("Sign out of Google?", isPresented: $confirmingSignOut) {
            Button("Stay signed in", role: .cancel) {}
            Button("Sign out", role: .destructive) {
                Task { await syncManager.signOut() }
            }
        } message: {
            // Pesolita Pro belongs to the Apple ID, not the Google account — signing out
            // does not cost the user their purchase, and should not sound like it does.
            Text("Your wallet stays on this iPhone and your backup stays in the cloud. New changes won't back up until you sign in again. Pesolita Pro stays on.")
        }
        .sheet(isPresented: $showingProUpsell) {
            ProUpsellView(store: store)
        }
        .fullScreenCover(isPresented: $attachingPhotoToUser) {
            ImagePicker { data in
                Task {
                    await store.attachUserPhoto(data)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Button { store.selectTab(.home) } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Tokens.dark3, in: Circle())
                }
                Spacer()
                Text("Settings")
                    .font(AppFont.outfit(14, weight: .semibold, relativeTo: .subheadline))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }

            HStack(spacing: 13) {
                Button {
                    attachingPhotoToUser = true
                } label: {
                    if let src = store.snapshot.userPhotoSrc, let url = store.mediaStore.url(for: src), let uiImage = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                    } else {
                        Text(initials)
                            .font(AppFont.outfit(20, weight: .black, relativeTo: .title3))
                            .foregroundStyle(Tokens.onAccent)
                            .frame(width: 52, height: 52)
                            .background(Tokens.accent, in: Circle())
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 5) {
                    if editingName {
                        TextField("Your name", text: $name)
                            .focused($nameFocused)
                            .font(AppFont.outfit(17, weight: .bold, relativeTo: .headline))
                            .foregroundStyle(Tokens.text)
                            .submitLabel(.done)
                            .onSubmit(commitName)
                            .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
                    } else {
                        Button {
                            editingName = true
                            nameFocused = true
                        } label: {
                            HStack(spacing: 7) {
                                Text(store.snapshot.userName.isEmpty ? "Pesolita friend" : store.snapshot.userName)
                                    .font(AppFont.outfit(17, weight: .bold, relativeTo: .headline))
                                    .foregroundStyle(Tokens.text)
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Tokens.text.opacity(0.55))
                                /* if store.isPro {
                                    Text("PRO")
                                        .font(AppFont.outfit(10, weight: .black))
                                        .foregroundStyle(Tokens.onAccent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Tokens.accent, in: Capsule())
                                } */
                            }
                            .frame(minHeight: 20)
                        }
                        .buttonStyle(.plain)
                    }
                    if store.isPro && syncManager.isAuthenticated {
                        Text("\(store.snapshot.cards.count) card\(store.snapshot.cards.count == 1 ? "" : "s") · Securely backed up to the cloud")
                            .font(AppFont.outfit(12, relativeTo: .caption))
                            .foregroundStyle(Tokens.text.opacity(0.45))
                    } else if store.isPro {
                        Text("\(store.snapshot.cards.count) card\(store.snapshot.cards.count == 1 ? "" : "s") · Backup is off")
                            .font(AppFont.outfit(12, relativeTo: .caption))
                            .foregroundStyle(Tokens.text.opacity(0.45))
                    } else {
                        Text("\(store.snapshot.cards.count) card\(store.snapshot.cards.count == 1 ? "" : "s") · 100% offline and private")
                            .font(AppFont.outfit(12, relativeTo: .caption))
                            .foregroundStyle(Tokens.text.opacity(0.45))
                    }
                }
                Spacer()
            }
            .padding(.top, 18)
        }
        .foregroundStyle(Tokens.text)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Tokens.background, in: UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
        .sheet(isPresented: $store.showProUpsell) {
            ProUpsellView(store: store)
        }
    }

    private func shareQRCodes() {
        var items: [Any] = []
        
        items.append("Hey! I use Pesolita to manage all my budget pockets and create payment QR codes in one tap. It’s free and super easy.\nGet it here: https://pesolita.vercel.app/about")
        if let promoImage = UIImage(named: "PromoBanner") {
            items.append(promoImage)
        }
        
        let qrImages: [UIImage] = store.snapshot.cards.compactMap { card in
            guard let ref = card.qr, let uiImage = ResourceImageLoader.image(reference: ref) else { return nil }
            return uiImage
        }
        items.append(contentsOf: qrImages)
        
        guard !qrImages.isEmpty, // Only share if there are actual QR codes to share
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            FeedbackCenter.warning()
            return
        }
        
        let avc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // For iPad support
        avc.popoverPresentationController?.sourceView = window
        avc.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
        avc.popoverPresentationController?.permittedArrowDirections = []
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        topVC.present(avc, animated: true)
    }

    private var initials: String {
        let words = (store.snapshot.userName.isEmpty ? "Pesolita" : store.snapshot.userName).split(separator: " ")
        return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private var separator: some View { EmptyView() }

    /// One row that always says what is true about the backup, and does the next useful thing.
    @ViewBuilder
    private var backupStatusRow: some View {
        let email = syncManager.email ?? "Google"
        switch syncManager.phase {
        case .signedOut:
            settingsRow(
                title: store.isPro ? "Back up with Google" : "Restore a backup",
                subtitle: store.isPro ? "This wallet isn't backed up yet" : "Used Pesolita Pro before? Bring your wallet back",
                symbol: store.isPro ? "icloud.and.arrow.up" : "icloud.and.arrow.down",
                tint: Tokens.link,
                iconBackground: Tokens.blueTint
            ) { store.openRestoreFlow(startSignIn: true) }
        case .reconciling:
            settingsRow(title: "Checking your backup…", subtitle: email, symbol: "icloud",
                        tint: Tokens.textSecondary, iconBackground: Tokens.fill) {}
        case .live:
            settingsRow(
                title: syncManager.isSyncing ? "Backing up…" : "Backed up",
                subtitle: lastBackupLine(email),
                symbol: "checkmark.icloud.fill",
                tint: Tokens.positive,
                iconBackground: Tokens.greenTint
            ) {}
        case .needsDecision:
            settingsRow(
                title: "Your backup needs a look",
                subtitle: "This iPhone and your backup differ — choose what to keep",
                symbol: "exclamationmark.icloud.fill",
                tint: Tokens.accentText,
                iconBackground: Tokens.accentTint
            ) { store.openRestoreFlow() }
        case .paused(.notPro):
            settingsRow(
                title: "Backup paused",
                subtitle: "Signed in as \(email) — Pesolita Pro isn't on this Apple ID",
                symbol: "icloud.slash",
                tint: Tokens.accentText,
                iconBackground: Tokens.accentTint
            ) { showingProUpsell = true }
        case .paused(.unreachable):
            settingsRow(
                title: "Couldn't reach your backup",
                subtitle: "Nothing changed. Tap to try again",
                symbol: "exclamationmark.icloud",
                tint: Tokens.negative,
                iconBackground: Tokens.redTint
            ) { Task { await syncManager.retry(store) } }
        }
    }

    private func lastBackupLine(_ email: String) -> String {
        guard let last = syncManager.lastSyncTime else { return email }
        return "\(email) · \(last.formatted(.relative(presentation: .named)))"
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Section(header: Text(title.uppercased())) {
            content()
                .listRowBackground(Tokens.dark2)
        }
    }

    private func settingsRowLabel(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        iconBackground: Color,
        isOn: Bool? = nil,
        danger: Bool = false,
        showMascot: Bool = false,
        showPriceBadge: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.outfit(13.5, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(danger ? Tokens.negative : Tokens.text)
                Text(subtitle)
                    .font(AppFont.outfit(11.5, relativeTo: .caption))
                    .foregroundStyle(Tokens.muted2)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if showMascot {
                HStack(spacing: 8) {
                    if showPriceBadge {
                        Text("₱49 only")
                            .font(AppFont.outfit(11, weight: .bold))
                            .foregroundStyle(Tokens.accentText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Tokens.accentTint, in: Capsule())
                    }
                    
                    Image("ProMascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .offset(y: isMascotFloating ? -4 : 4)
                }
            } else if let isOn { 
                WebToggle(isOn: isOn) 
            }
        }
        .padding(.vertical, 4)
    }

    private func settingsRow(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        iconBackground: Color,
        isOn: Bool? = nil,
        danger: Bool = false,
        showMascot: Bool = false,
        showPriceBadge: Bool = false,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsRowLabel(title: title, subtitle: subtitle, symbol: symbol, tint: tint, iconBackground: iconBackground, isOn: isOn, danger: danger, showMascot: showMascot, showPriceBadge: showPriceBadge)
        }
        .accessibilityIdentifier(identifier ?? title)
    }

    private func commitName() {
        store.renameUser(name)
        name = store.snapshot.userName
        editingName = false
        nameFocused = false
    }

    private func exportBackup() {
        guard !store.snapshot.cards.isEmpty else {
            store.showToast("Nothing to back up yet.")
            FeedbackCenter.warning()
            return
        }
        Task { @MainActor in
            do {
                exportDocument = PesolitaExportDocument(data: try await store.backupData())
                exportContentType = .json
                exportFilename = backupFilename
                exportSuccessMessage = "Backup saved."
                // Let SwiftUI observe the new document before asking it to present the
                // exporter; otherwise the sheet can capture the initial empty document.
                await Task.yield()
                exportingFile = true
            } catch { store.showToast("Could not create the backup.") }
        }
    }

    private func exportCSV() {
        guard !store.snapshot.tx.isEmpty else { store.showToast("Nothing to export yet."); return }
        exportDocument = PesolitaExportDocument(data: store.csvData())
        exportContentType = .commaSeparatedText
        exportFilename = "pesolita-transactions"
        exportSuccessMessage = "CSV saved."
        Task { @MainActor in
            await Task.yield()
            exportingFile = true
        }
    }

    private func exportFinished(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            store.showToast(exportSuccessMessage)
            FeedbackCenter.success()
        case .failure(let error) where isCancellation(error):
            break
        case .failure:
            store.showToast("The file could not be saved.")
            FeedbackCenter.warning()
        }
    }

    private func prepareRestore(_ result: Result<URL, Error>) async {
        guard case .success(let url) = result else {
            if case .failure(let error) = result, !isCancellation(error) {
                store.showToast("That backup could not be opened.")
            }
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            pendingRestore = try Data(contentsOf: url)
            confirmingRestore = true
            FeedbackCenter.opened()
        } catch {
            store.showToast("That backup could not be read.")
            FeedbackCenter.warning()
        }
    }

    private var backupFilename: String {
        let day = ISO8601DateFormatter().string(from: .now).prefix(10)
        return "pesolita-backup-\(day)"
    }

    private func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}

struct WebToggle: View {
    var isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Tokens.green : Tokens.fillStrong)
            .frame(width: 42, height: 25)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(.white).frame(width: 19, height: 19).padding(3)
            }
            .animation(Tokens.easeOut(0.26), value: isOn)
            .accessibilityHidden(true)
    }
}
