import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Bindable var store: WalletStore
    @State private var showImporter = false
    @State private var balanceField = ""
    @FocusState private var focusedField: Field?

    private enum Field { case name, nickname, balance }

    var body: some View {
        ZStack {
            Tokens.ink.ignoresSafeArea()
            VStack(spacing: 0) {
                brandHeader
                Group {
                    switch store.onboarding.step {
                    case 0: introStep
                    case 1: nameStep
                    case 2: chooseCardStep
                    default: fundingStep
                    }
                }
                .id(store.onboarding.step)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                pageDots
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .font(AppFont.outfit(16))
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .data]) { result in
            guard case let .success(url) = result else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                Task { await store.restoreBackup(data) }
            } catch {
                store.showToast("That backup could not be opened.")
                FeedbackCenter.warning()
            }
        }
        .animation(Tokens.easeOut(0.38), value: store.onboarding.step)
    }

    private var brandHeader: some View {
        HStack(spacing: 8) {
            MascotMarkView(size: 20)
            Text("Pesolita")
                .font(AppFont.outfit(15, weight: .bold, relativeTo: .subheadline))
            Spacer()
        }
        .padding(.horizontal, 26)
        .frame(height: 40)
    }

    private var introStep: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack {
                    fanCard(style: .blob, colors: ("#16161a", "#ffca28"), rotation: -13, x: -28, y: 4)
                    fanCard(style: .wave, colors: ("#0b8f6a", "#f4eedc"), rotation: -6.5, x: -14, y: -2)
                    fanCard(style: .arc, colors: ("#ffca28", "#0b0b0c"), rotation: 0, x: 0, y: -8)
                    fanCard(style: .grid, colors: ("#1d6ff2", "#f4eedc"), rotation: 6.5, x: 15, y: -14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(minHeight: 250)

            VStack(alignment: .leading, spacing: 0) {
                Text("Every peso\ngets a home.")
                    .font(AppFont.outfit(38, weight: .black, relativeTo: .largeTitle))
                    .tracking(-1.25)
                    .lineSpacing(-2)
                Text("Make a card for each pocket of your money — bank, e-wallet, the cash in your actual wallet. You type it in, nothing snoops your bank.")
                    .font(AppFont.outfit(14.5, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineSpacing(5)
                    .padding(.top, 14)

                primaryButton("Let's make your first card", symbol: "arrow.right") {
                    store.onboarding.step = 1
                    focusedField = .name
                }
                .padding(.top, 25)

                Button("Been here before? Restore a backup") { showImporter = true }
                    .font(AppFont.outfit(12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 8)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            SpriteAnimationView(spec: .peekaboo, size: 150)
                .offset(x: -10)
            Text("First — what\nshould I call you?")
                .font(AppFont.outfit(30, weight: .black, relativeTo: .title))
                .tracking(-0.8)
                .lineSpacing(-2)
            Text("Just a first name is fine. It stays on this phone with everything else.")
                .font(AppFont.outfit(13.5, relativeTo: .subheadline))
                .foregroundStyle(.white.opacity(0.50))
                .lineSpacing(3)
                .padding(.top, 9)

            darkField(label: "YOUR NAME") {
                TextField("Your name", text: $store.onboarding.name)
                    .textContentType(.givenName)
                    .submitLabel(.continue)
                    .font(AppFont.outfit(24, weight: .bold, relativeTo: .title2))
                    .focused($focusedField, equals: .name)
                    .onSubmit { if !store.onboarding.name.trimmingCharacters(in: .whitespaces).isEmpty { store.onboarding.step = 2 } }
            }
            .padding(.top, 26)

            Text(store.onboarding.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Nice to meet you." : "Hi, \(store.onboarding.name.split(separator: " ").first ?? "").")
                .font(AppFont.outfit(15, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Tokens.accent)
                .padding(.top, 16)
            Spacer()
            primaryButton("Continue") {
                focusedField = nil
                store.onboarding.step = 2
            }
            .accessibilityIdentifier("onboarding-name-continue")
            .opacity(store.onboarding.name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.32 : 1)
            .disabled(store.onboarding.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    /// Category and template used to be two screens, which made picking a card feel like
    /// paperwork: choose a kind, wait for a push, choose a look, and push again to correct
    /// the kind. Together they are a single decision — "which card is this?" — so they now
    /// share one screen where changing the category re-filters the carousel in place.
    private var chooseCardStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Choose your card.")
                .font(AppFont.outfit(30, weight: .black, relativeTo: .title))
                .tracking(-0.8)
            Text("Pick a category, then a look. You can refine it later.")
                .font(AppFont.outfit(13.5, relativeTo: .subheadline))
                .foregroundStyle(.white.opacity(0.5))
                .lineSpacing(3)
                .padding(.top, 8)

            categoryChips
                .padding(.top, 18)

            // Slack is split above and below so the panel sits centred in whatever room the
            // chips leave, rather than pinning to the chips with a gap over the button.
            Spacer(minLength: 16)

            templatePanel

            Spacer(minLength: 16)

            primaryButton(store.onboarding.kind == .cash ? "Use cash on hand" : "Use this template") {
                store.onboarding.step = 3
            }
            .disabled(store.onboarding.kind == nil)
            .opacity(store.onboarding.kind == nil ? 0.4 : 1)
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var categoryChips: some View {
        FlowLayout(spacing: 7, lineSpacing: 7) {
            ForEach(CardKind.onboardingKinds) { kind in
                let selected = store.onboarding.kind == kind
                Button { store.selectKind(kind) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 12.5, weight: .semibold))
                            .frame(width: 23, height: 23)
                            .background(
                                selected ? Color.black.opacity(0.12) : Color.white.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        Text(kind.label)
                            .font(AppFont.outfit(13, weight: .semibold, relativeTo: .subheadline))
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 13)
                    .frame(height: 44)
                    .foregroundStyle(selected ? Tokens.ink : .white)
                    .background(selected ? Tokens.accent : Tokens.dark1, in: Capsule())
                    .overlay {
                        Capsule().stroke(selected ? .clear : .white.opacity(0.10), lineWidth: 1)
                    }
                }
                .buttonStyle(PesolitaPressStyle())
                .accessibilityIdentifier("kind-\(kind.id)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .animation(Tokens.easeOut(0.28), value: store.onboarding.kind)
    }

    @ViewBuilder
    private var templatePanel: some View {
        // The panel is a background rather than a ZStack layer: a bare RoundedRectangle is
        // infinitely flexible and would stretch the panel to fill the screen.
        Group {
            if let kind = store.onboarding.kind, let category = kind.templateCategory {
                CardTemplatePickerView(
                    category: category,
                    selectedID: store.onboarding.templateID,
                    onDark: true,
                    onSelect: store.selectTemplate
                )
                .padding(.vertical, 18)
                .id(category)
                .transition(.opacity)
            } else if store.onboarding.kind == .cash {
                // Cash has no artwork to browse — saying so beats an empty carousel.
                VStack(spacing: 12) {
                    CardFaceView(card: previewCard, showFreeze: false)
                        .frame(maxWidth: 232)
                        .shadow(color: .black.opacity(0.45), radius: 16, y: 12)
                    Text("Cash needs no template.")
                        .font(AppFont.outfit(13.5, weight: .semibold, relativeTo: .subheadline))
                    Text("Name it and count it on the next step.")
                        .font(AppFont.outfit(11.5, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.42))
                }
                .padding(.vertical, 22)
                .transition(.opacity)
            } else {
                VStack(spacing: 9) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white.opacity(0.34))
                    Text("Pick a category to see cards.")
                        .font(AppFont.outfit(12.5, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(0.42))
                }
                .padding(.vertical, 46)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Tokens.dark1)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
                }
        }
        .animation(Tokens.easeOut(0.3), value: store.onboarding.kind)
    }

    private var fundingStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("Name it, fund it.")
                        .font(AppFont.outfit(27, weight: .black, relativeTo: .title2))
                    Spacer()
                    smallChangeButton("Change card") { store.onboarding.step = 2 }
                }

                CardFaceView(card: previewCard, showFreeze: false)
                    .frame(maxWidth: 286)
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.45), radius: 17, y: 14)
                    .padding(.top, 18)

                darkField(label: "NICKNAME") {
                    TextField("Give it a name", text: $store.onboarding.nickname)
                        .font(AppFont.outfit(17, weight: .semibold, relativeTo: .body))
                        .focused($focusedField, equals: .nickname)
                }
                .padding(.top, 22)

                darkField(label: "WHAT'S IN IT RIGHT NOW") {
                    HStack(spacing: 7) {
                        Text("₱").font(AppFont.outfit(23, weight: .semibold, relativeTo: .title2))
                        // A computed Binding cannot do this: while the field has focus
                        // SwiftUI keeps its own editing buffer and never re-reads `get`,
                        // so the grouping would only appear after the field lost focus.
                        // Local state is the source of truth the field will actually honour.
                        TextField("0.00", text: $balanceField)
                            .keyboardType(.decimalPad)
                            .font(AppFont.outfit(27, weight: .bold, relativeTo: .title2))
                            .focused($focusedField, equals: .balance)
                            .accessibilityIdentifier("onboarding-balance")
                            .onAppear { balanceField = MoneyFormat.grouped(draft: store.onboarding.balance) }
                            .onChange(of: balanceField) { _, typed in
                                let raw = MoneyFormat.ungrouped(typed)
                                let grouped = MoneyFormat.grouped(draft: raw)
                                if grouped != typed { balanceField = grouped }
                                store.onboarding.balance = raw
                            }
                    }
                }
                .padding(.top, 10)

                primaryButton("Create card") {
                    focusedField = nil
                    store.finishOnboarding()
                }
                .padding(.top, 24)
                .accessibilityIdentifier("create-card")
                Text("You can redesign the card any time.")
                    .font(AppFont.outfit(11, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private var previewCard: Card {
        Card(
            id: "preview",
            kind: store.onboarding.kind ?? .debit,
            nick: store.onboarding.nickname.isEmpty ? "Untitled card" : store.onboarding.nickname,
            last4: "",
            exp: "—",
            bal: Double(store.onboarding.balance) ?? 0,
            limit: 0,
            art: store.onboarding.art,
            frozen: false
        )
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == store.onboarding.step ? Tokens.accent : Color.white.opacity(0.22))
                    .frame(width: index == store.onboarding.step ? 22 : 4, height: 4)
            }
        }
        .frame(height: 26)
        .animation(Tokens.easeSpring(0.38), value: store.onboarding.step)
    }

    private func fanCard(style: CardArtStyle, colors: (String, String), rotation: Double, x: CGFloat, y: CGFloat) -> some View {
        CardArtView(art: CardArt(style: style, c1: colors.0, c2: colors.1, tex: .grain, layout: .standard), cornerRadius: 18)
            .frame(width: 232)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
            .shadow(color: .black.opacity(0.42), radius: 15, y: 14)
    }

    private func darkField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.outfit(10.5, weight: .medium, relativeTo: .caption2))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.38))
            content().tint(Tokens.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Tokens.dark2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func primaryButton(_ title: String, symbol: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                if let symbol { Image(systemName: symbol) }
            }
            .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
            .foregroundStyle(Tokens.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Tokens.accent, in: Capsule())
            .shadow(color: Tokens.accent.opacity(0.28), radius: 15, y: 12)
        }
        .buttonStyle(.plain)
    }

    private func smallChangeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(AppFont.outfit(10.5, weight: .semibold, relativeTo: .caption2))
            .foregroundStyle(.white.opacity(0.66))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(.white.opacity(0.08), in: Capsule())
    }
}
