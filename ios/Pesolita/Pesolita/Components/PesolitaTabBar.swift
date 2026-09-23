import SwiftUI

struct PesolitaTabBar: View {
    @Bindable var store: WalletStore

    var body: some View {
        let isCompact = store.isScrolledDown
        
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                tab(.home, isCompact: isCompact)
                tab(.insights, isCompact: isCompact)
                Color.clear.frame(maxWidth: .infinity)
                tab(.search, isCompact: isCompact)
                tab(.settings, isCompact: isCompact)
            }
            .padding(.horizontal, isCompact ? 6 : 8)
            .frame(height: isCompact ? 50 : 66)
            // Material alone goes nearly black over a dark page and picks up whatever bright
            // button scrolls beneath it. A tinted layer keeps the bar one steady surface.
            .background {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(Tokens.surfaceOverlay.opacity(0.78))
                }
            }
            .pesolitaElevation(.floating, in: Capsule())

            Button {
                store.openTransaction(.withdraw)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: isCompact ? 18 : 22, weight: .bold))
                    .foregroundStyle(Tokens.onBrand)
                    .frame(width: isCompact ? 44 : 56, height: isCompact ? 44 : 56)
                    .background(Tokens.blue, in: Circle())
                    .shadow(color: Tokens.blue.opacity(0.42), radius: 12, y: 8)
            }
            .buttonStyle(.plain)
            .offset(y: isCompact ? -12 : -20)
            .accessibilityLabel("Log a spend")
            .accessibilityIdentifier("log-spend-fab")
        }
        .frame(height: isCompact ? 52 : 68)
        .padding(.horizontal, isCompact ? 32 : 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isCompact)
    }

    private func tab(_ tab: MainTab, isCompact: Bool) -> some View {
        Button {
            store.selectTab(tab)
        } label: {
            Image(systemName: store.selectedTab == tab ? tab.selectedSymbol : tab.symbol)
                .font(.system(size: isCompact ? 17 : 21, weight: .medium))
                .foregroundStyle(store.selectedTab == tab ? Tokens.text : .secondary)
                .frame(maxWidth: .infinity, minHeight: isCompact ? 40 : 56)
                .background(store.selectedTab == tab ? Tokens.dark2 : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(store.selectedTab == tab ? .isSelected : [])
    }
}

struct PesolitaRail: View {
    @Bindable var store: WalletStore

    var body: some View {
        VStack(spacing: 10) {
            MascotMarkView(size: 43)
                .padding(.top, 10)
                .padding(.bottom, 14)
            ForEach(MainTab.allCases) { tab in
                Button { store.selectTab(tab) } label: {
                    VStack(spacing: 5) {
                        Image(systemName: store.selectedTab == tab ? tab.selectedSymbol : tab.symbol)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tab.title)
                            .font(AppFont.outfit(9.5, weight: .bold, relativeTo: .caption2))
                    }
                    .foregroundStyle(store.selectedTab == tab ? Tokens.background : Tokens.muted2)
                    .frame(width: 60, height: 58)
                    .background(store.selectedTab == tab ? Tokens.text : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PesolitaPressStyle())
                .accessibilityAddTraits(store.selectedTab == tab ? .isSelected : [])
            }
            Spacer()
            Button { store.openTransaction(.withdraw) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Tokens.onBrand)
                    .frame(width: 56, height: 56)
                    .background(Tokens.blue, in: Circle())
                    .shadow(color: Tokens.blue.opacity(0.35), radius: 10, y: 5)
            }
            .buttonStyle(PesolitaPressStyle())
            .accessibilityLabel("Log a spend")
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 8)
        .frame(width: 82)
        .background(Tokens.background)
    }
}
