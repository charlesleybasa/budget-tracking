import SwiftUI

struct PesolitaTabBar: View {
    @Bindable var store: WalletStore

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                tab(.home)
                tab(.insights)
                Color.clear.frame(maxWidth: .infinity)
                tab(.search)
                tab(.settings)
            }
            .padding(.horizontal, 8)
            .frame(height: 66)
            .background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 15, y: 5)

            Button {
                store.openTransaction(.withdraw)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Tokens.blue, in: Circle())
                    .shadow(color: Tokens.blue.opacity(0.42), radius: 12, y: 8)
            }
            .buttonStyle(.plain)
            .offset(y: -20)
            .accessibilityLabel("Log a spend")
            .accessibilityIdentifier("log-spend-fab")
        }
        .frame(height: 68)
        .padding(.horizontal, 16)
    }

    private func tab(_ tab: MainTab) -> some View {
        Button {
            store.selectTab(tab)
        } label: {
            Image(systemName: store.selectedTab == tab ? tab.selectedSymbol : tab.symbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(store.selectedTab == tab ? Tokens.ink : Tokens.muted4)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(store.selectedTab == tab ? Tokens.sand2 : .clear, in: Capsule())
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
                    .foregroundStyle(store.selectedTab == tab ? Tokens.ink : .white.opacity(0.48))
                    .frame(width: 60, height: 58)
                    .background(store.selectedTab == tab ? .white : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PesolitaPressStyle())
                .accessibilityAddTraits(store.selectedTab == tab ? .isSelected : [])
            }
            Spacer()
            Button { store.openTransaction(.withdraw) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
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
        .background(Tokens.ink)
    }
}
