import SwiftUI
import PhotosUI

struct RootView: View {
    @Bindable var store: WalletStore
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            if !store.hydrated {
                splash
            } else if !store.snapshot.onboarded {
                OnboardingView(store: store)
            } else {
                mainApp
            }

            if let success = store.success {
                SuccessView(success: success, onClose: store.closeSuccess)
                    .zIndex(20)
                    .transition(.opacity)
            }

            if let toast = store.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(AppFont.outfit(13, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Tokens.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 46)
                        .background(Tokens.darkHover, in: Capsule())
                        .shadow(color: .black.opacity(0.30), radius: 12, y: 8)
                        .padding(.horizontal, 24)
                        .padding(.bottom, store.snapshot.onboarded ? 96 : 22)
                }
                .zIndex(30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .animation(Tokens.easeOut(0.25), value: store.toast)
        .animation(Tokens.easeOut(0.28), value: store.success?.id)
        .sheet(isPresented: Binding(
            get: { store.sheet != nil },
            set: { if !$0 { store.dismissSheet() } }
        )) {
            SpendSheetView(store: store)
        }
        .sheet(isPresented: Binding(
            get: { store.transactionEditor != nil },
            set: { if !$0 { store.transactionEditor = nil } }
        )) {
            TransactionEditorView(store: store)
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.qrViewerCardID != nil },
            set: { if !$0 { store.qrViewerCardID = nil } }
        )) {
            if let id = store.qrViewerCardID,
               let card = store.snapshot.cards.first(where: { $0.id == id }) {
                if let qr = card.qr {
                    let shareText = "Hey! Send money to my account instantly. 💸 Just scan this QR Code using any payment app! I made this using the Pesolita App.\nGet it here: https://pesolita.vercel.app/about"
                    let shareItems: [Any] = [shareText, ResourceImageLoader.image(reference: qr)].compactMap { $0 }
                    ResourceViewer(title: card.nick, subtitle: "Receiving QR", reference: qr, onClose: {
                        store.qrViewerCardID = nil
                    }, shareItems: shareItems)
                } else {
                    EmptyQRViewer(store: store, card: card) {
                        store.qrViewerCardID = nil
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.receiptViewerTransactionID != nil },
            set: { if !$0 { store.receiptViewerTransactionID = nil } }
        )) {
            if let id = store.receiptViewerTransactionID,
               let transaction = store.snapshot.tx.first(where: { $0.id == id }),
               let receipt = transaction.receipt {
                ResourceViewer(title: transaction.merchant, subtitle: "Receipt", reference: receipt) {
                    store.receiptViewerTransactionID = nil
                }
            }
        }
        .alert("Delete this card?", isPresented: $store.cardDeleteOpen) {
            Button("Keep it", role: .cancel) {}
            Button("Delete card", role: .destructive) { store.deleteEditorCard() }
        } message: {
            Text("The card and its activity will be removed. This cannot be undone.")
        }
        .alert("Erase all Pesolita data?", isPresented: $store.eraseOpen) {
            Button("Cancel", role: .cancel) {}
            Button("Erase everything", role: .destructive) {
                Task {
                    // Sign out before erasing, so the empty wallet can never reach the backup.
                    let hadBackup = syncManager.isAuthenticated
                    await syncManager.prepareForReset()
                    await store.resetEverything()
                    if hadBackup { store.showToast("This phone is clear. Your cloud backup is safe.") }
                }
            }
        } message: {
            Text(syncManager.isAuthenticated
                 ? "Every card, transaction and receipt on this iPhone will be deleted. Your Pesolita Pro cloud backup is kept — sign in with Google any time to bring it back."
                 : "Every card, transaction, receipt and preference on this device will be deleted. Export a backup first if you may want them later.")
        }
        .alert("Wallet recovery", isPresented: Binding(
            get: { store.loadError != nil },
            set: { if !$0 { store.loadError = nil } }
        )) {
            Button("Start fresh", role: .cancel) { store.loadError = nil }
        } message: {
            Text(store.loadError ?? "")
        }
        // Attached here, not to the main app, because onboarding is where most people look for
        // "Restore your wallet" — and the main app does not exist yet while it is showing.
        .sheet(isPresented: $store.restoreFlowOpen) {
            RestoreFlowView(store: store, startsWithChoice: !store.restoreFlowStartsSignIn)
                .preferredColorScheme(store.snapshot.appTheme.colorScheme)
        }
        .onChange(of: syncManager.phase) { _, phase in
            // A reinstall keeps the Google session, so the app can know on launch that a
            // backup is waiting. Offer it straight away instead of waiting to be found.
            if case .needsDecision(.restore) = phase, !store.snapshot.onboarded, !store.restoreFlowOpen {
                store.openRestoreFlow()
            }
        }
    }

    private var mainApp: some View {
        NavigationStack(path: $store.path) {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 0) {
                        PesolitaRail(store: store)
                        tabContent
                            .frame(maxWidth: 720)
                            .frame(maxWidth: .infinity)
                    }
                    .background(store.selectedTab == .home ? Tokens.background : Tokens.dark1)
                } else {
                    ZStack(alignment: .bottom) {
                        tabContent
                        PesolitaTabBar(store: store)
                            .padding(.bottom, 8)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // A decision found in the background (another device wrote, or a fresh start
                // met an old backup) is a question, not an emergency: a quiet banner on Home
                // rather than a sheet thrown over whatever the user was doing.
                if store.selectedTab == .home, case .needsDecision = syncManager.phase, !store.restoreFlowOpen {
                    BackupAttentionBanner { store.openRestoreFlow() }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(Tokens.easeOut(0.3), value: syncManager.phase)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .detail(let id): CardDetailView(store: store, cardID: id)
                case .editor: CardEditorView(store: store)
                case .transfer: TransferView(store: store)
                case .people: PeopleView(store: store)
                case .events: EventsView(store: store)
                case .event(let id): EventDetailView(store: store, eventID: id)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { store.pendingDebt != nil },
            set: { if !$0 { store.cancelSettle() } }
        )) {
            if let debt = store.pendingDebt {
                SettleSliderView(store: store, debt: debt)
                    .presentationDetents([.height(500)])
                    .presentationBackground(.regularMaterial)
            }
        }
        .preferredColorScheme(store.snapshot.appTheme.colorScheme)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .home: HomeView(store: store)
        case .insights: InsightsView(store: store)
        case .search: SearchView(store: store)
        case .settings: SettingsView(store: store)
        }
    }

    private var splash: some View {
        ZStack {
            Tokens.background.ignoresSafeArea()
            MascotMarkView(size: 52)
                .accessibilityLabel("Pesolita")
        }
    }
}

private struct EmptyQRViewer: View {
    var store: WalletStore
    var card: Card
    var onDismiss: () -> Void
    
    @State private var qrPhoto: PhotosPickerItem?
    
    var body: some View {
        ZStack {
            Tokens.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Tokens.muted2)
                Text("No QR Code")
                    .font(AppFont.outfit(24, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(Tokens.text)
                Text("You haven't attached a receiving QR code for \(card.nick) yet.")
                    .font(AppFont.outfit(15, relativeTo: .body))
                    .foregroundStyle(Tokens.muted2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                
                PhotosPicker(selection: $qrPhoto, matching: .images) {
                    Text("Choose from Gallery")
                        .font(AppFont.outfit(15, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(Tokens.text)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Tokens.dark1, in: Capsule())
                }
                .buttonStyle(PesolitaPressStyle())
                .padding(.horizontal, 24)
                
                Button("Close", action: onDismiss)
                    .font(AppFont.outfit(15, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Tokens.text.opacity(0.5))
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
        }
        .onChange(of: qrPhoto) { _, item in
            if let item = item {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await store.attachQRToCard(cardID: card.id, data: data)
                        onDismiss()
                    }
                }
            }
        }
    }
}

/// "Your backup needs a look" — shown on Home when this iPhone and the backup disagree.
struct BackupAttentionBanner: View {
    var review: () -> Void

    var body: some View {
        Button(action: review) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.accentText)
                    .frame(width: 34, height: 34)
                    .background(Tokens.accentTint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your backup needs a look")
                        .font(AppFont.outfit(14, weight: .bold))
                        .foregroundStyle(Tokens.textPrimary)
                    Text("This iPhone and your backup differ. Nothing is lost.")
                        .font(AppFont.outfit(12))
                        .foregroundStyle(Tokens.textSecondary)
                }
                Spacer(minLength: 4)
                Text("Review")
                    .font(AppFont.outfit(12.5, weight: .bold))
                    .foregroundStyle(Tokens.onAccent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(Tokens.accent, in: Capsule())
            }
            .padding(12)
            .background(Tokens.surfaceOverlay, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .pesolitaElevation(.floating, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityHint("Opens the choice between this iPhone's wallet and your backup")
    }
}
