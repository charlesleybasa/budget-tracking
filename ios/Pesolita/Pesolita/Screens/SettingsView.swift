import SwiftUI
import UniformTypeIdentifiers

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

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        settingsGroup("Money") {
                            settingsRow(
                                title: "Card limits",
                                subtitle: store.activeCard.map { "Edit \($0.nick)" } ?? "Add a card first",
                                symbol: "chart.bar.fill",
                                tint: Color(hex: "#a4801a"),
                                iconBackground: Color(hex: "#ffca2833")
                            ) { store.activeCard.map { store.openEditor(cardID: $0.id) } }
                        }

                        settingsGroup("Nudges") {
                            VStack(spacing: 0) {
                                settingsRow(
                                    title: "Low balance nudge",
                                    subtitle: "When a card drops under ₱1,500",
                                    symbol: "exclamationmark.triangle",
                                    tint: Tokens.red,
                                    iconBackground: Tokens.red.opacity(0.14),
                                    isOn: store.snapshot.nudgeLowBalance,
                                    action: store.toggleLowBalanceNudge
                                )
                                separator
                                settingsRow(
                                    title: "Daily log reminder",
                                    subtitle: "A nudge at 9pm — needs notification permission",
                                    symbol: "bell",
                                    tint: Color(hex: "#7c3aed"),
                                    iconBackground: Color(hex: "#7c3aed22"),
                                    isOn: store.snapshot.nudgeDailyLog
                                ) { Task { await store.toggleDailyReminder() } }
                            }
                        }

                        settingsGroup("Feel") {
                            VStack(spacing: 0) {
                                settingsRow(
                                    title: "Haptics",
                                    subtitle: "A short buzz on every tap and total",
                                    symbol: "iphone.radiowaves.left.and.right",
                                    tint: Tokens.blue,
                                    iconBackground: Tokens.blue.opacity(0.12),
                                    isOn: store.snapshot.haptics,
                                    action: store.toggleHaptics
                                )
                                separator
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
                        }

                        settingsGroup("Your data") {
                            VStack(spacing: 0) {
                                settingsRow(
                                    title: "Hide balances",
                                    subtitle: "Blur every number on unlock",
                                    symbol: "eye",
                                    tint: Tokens.ink,
                                    iconBackground: Tokens.ink.opacity(0.08),
                                    isOn: store.snapshot.privacy,
                                    action: store.togglePrivacy
                                )
                                separator
                                settingsRow(title: "Back up wallet", subtitle: "Cards, history and settings as one file", symbol: "arrow.down", tint: Tokens.green, iconBackground: Tokens.green.opacity(0.12), identifier: "backup-wallet", action: exportBackup)
                                separator
                                settingsRow(title: "Restore from backup", subtitle: "Replaces everything on this device", symbol: "arrow.up", tint: Tokens.blue, iconBackground: Tokens.blue.opacity(0.12), identifier: "restore-wallet") { importingBackup = true }
                                    .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json, .data]) { result in
                                        Task { @MainActor in await prepareRestore(result) }
                                    }
                                separator
                                settingsRow(title: "Export CSV", subtitle: "Transactions only, for a spreadsheet", symbol: "doc.text", tint: Tokens.ink, iconBackground: Tokens.ink.opacity(0.08), action: exportCSV)
                                separator
                                settingsRow(title: "Start over", subtitle: "Erase all cards and history from this device", symbol: "trash", tint: Tokens.redDeep, iconBackground: Tokens.red.opacity(0.12), danger: true) {
                                    store.eraseOpen = true
                                    FeedbackCenter.warning()
                                }
                            }
                        }

                        Text("Pesolita 1.0 · Your numbers never leave this device.")
                            .font(AppFont.outfit(11.5, relativeTo: .caption))
                            .foregroundStyle(Tokens.muted3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 96)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.light)
        .onAppear { name = store.snapshot.userName }
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
                Text(initials)
                    .font(AppFont.outfit(20, weight: .black, relativeTo: .title3))
                    .foregroundStyle(Tokens.ink)
                    .frame(width: 52, height: 52)
                    .background(Tokens.accent, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    if editingName {
                        TextField("Your name", text: $name)
                            .focused($nameFocused)
                            .font(AppFont.outfit(17, weight: .bold, relativeTo: .headline))
                            .foregroundStyle(.white)
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
                                    .foregroundStyle(.white)
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .frame(minHeight: 20)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(store.snapshot.cards.count) card\(store.snapshot.cards.count == 1 ? "" : "s") · nothing connected to a bank")
                        .font(AppFont.outfit(12, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
            }
            .padding(.top, 18)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Tokens.ink, in: UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
    }

    private var initials: String {
        let words = (store.snapshot.userName.isEmpty ? "Pesolita" : store.snapshot.userName).split(separator: " ")
        return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private var separator: some View { Divider().overlay(Tokens.line3) }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(AppFont.outfit(11, weight: .semibold, relativeTo: .caption))
                .tracking(1.1)
                .foregroundStyle(Tokens.muted3)
            content()
                .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func settingsRow(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        iconBackground: Color,
        isOn: Bool? = nil,
        danger: Bool = false,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFont.outfit(13.5, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(danger ? Tokens.redDeep : Tokens.ink)
                    Text(subtitle)
                        .font(AppFont.outfit(11.5, relativeTo: .caption))
                        .foregroundStyle(Tokens.muted2)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if let isOn { WebToggle(isOn: isOn) }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
        }
        .buttonStyle(PesolitaPressStyle())
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
            .fill(isOn ? Tokens.green : Color(hex: "#dcdbd5"))
            .frame(width: 42, height: 25)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(.white).frame(width: 19, height: 19).padding(3)
            }
            .animation(Tokens.easeOut(0.26), value: isOn)
            .accessibilityHidden(true)
    }
}
