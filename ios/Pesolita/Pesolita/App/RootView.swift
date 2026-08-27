import SwiftUI

struct RootView: View {
    @Bindable var store: WalletStore
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
                        .foregroundStyle(.white)
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
               let card = store.snapshot.cards.first(where: { $0.id == id }),
               let qr = card.qr {
                ResourceViewer(title: card.nick, subtitle: "Receiving QR", reference: qr) {
                    store.qrViewerCardID = nil
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
                Task { await store.resetEverything() }
            }
        } message: {
            Text("Every card, transaction, receipt and preference on this device will be deleted. Export a backup first if you may want them later.")
        }
        .alert("Wallet recovery", isPresented: Binding(
            get: { store.loadError != nil },
            set: { if !$0 { store.loadError = nil } }
        )) {
            Button("Start fresh", role: .cancel) { store.loadError = nil }
        } message: {
            Text(store.loadError ?? "")
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
                    .background(store.selectedTab == .home ? Tokens.ink : Tokens.sand1)
                } else {
                    ZStack(alignment: .bottom) {
                        tabContent
                        PesolitaTabBar(store: store)
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .detail(let id): CardDetailView(store: store, cardID: id)
                case .editor: CardEditorView(store: store)
                case .transfer: TransferView(store: store)
                }
            }
        }
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
            Tokens.ink.ignoresSafeArea()
            MascotMarkView(size: 52)
                .accessibilityLabel("Pesolita")
        }
    }
}
