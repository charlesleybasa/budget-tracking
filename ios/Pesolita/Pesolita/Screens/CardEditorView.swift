import PhotosUI
import SwiftUI

struct CardEditorView: View {
    @Bindable var store: WalletStore
    @State private var templateCategory: TemplateCategory = .banks
    @State private var artworkPhoto: PhotosPickerItem?
    @State private var qrPhoto: PhotosPickerItem?
    @State private var detailsExpanded = true

    private var draft: CardEditorDraft? { store.editor }
    private var card: Card? { draft?.card }
    private var selectedTemplate: CardTemplate? {
        guard let path = card?.art.photo?.src else { return nil }
        return CardTemplates.all.first { $0.art.photo?.src == path }
    }

    var body: some View {
        ZStack {
            Tokens.ink.ignoresSafeArea()
            if let draft {
                ScrollView {
                    VStack(spacing: 0) {
                        editorHeader(draft)
                        controlsPanel(draft)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            if let category = selectedTemplate?.category { templateCategory = category }
        }
        .onChange(of: artworkPhoto) { _, item in importPhoto(item, qr: false) }
        .onChange(of: qrPhoto) { _, item in importPhoto(item, qr: true) }
    }

    private func editorHeader(_ draft: CardEditorDraft) -> some View {
        VStack(spacing: 17) {
            HStack {
                Button {
                    store.editor = nil
                    store.popRoute()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 48, height: 48)
                        .background(Tokens.dark2, in: Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(draft.isNew ? "New card" : "Redesign card")
                        .font(AppFont.outfit(19, weight: .black, relativeTo: .title3))
                    Text(draft.mode == .templates ? "Template" : "DIY")
                        .font(AppFont.outfit(10.5, relativeTo: .caption2))
                        .foregroundStyle(.white.opacity(0.38))
                }
                Spacer()
                Button { store.saveEditorCard() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Tokens.ink)
                        .frame(width: 48, height: 48)
                        .background(Tokens.accent, in: Circle())
                }
            }
            .foregroundStyle(.white)

            CardFaceView(card: draft.card, privateMode: false)
                .frame(width: 320, height: 196)
                .id(draft.card.art)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(Tokens.easeOut(0.26), value: draft.card.art)
                .accessibilityIdentifier("card-editor-preview")

            HStack(spacing: 8) {
                modeButton(.templates, icon: "rectangle.stack.fill", label: "Templates")
                modeButton(.diy, icon: "paintpalette.fill", label: "DIY")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 24)
    }

    private func controlsPanel(_ draft: CardEditorDraft) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if draft.mode == .templates { templateControls(draft) }
            else { diyControls(draft) }
            detailsControls(draft)
            saveControls(draft)
        }
        .foregroundStyle(Tokens.ink)
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 58)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
        .preferredColorScheme(.light)
    }

    private func templateControls(_ draft: CardEditorDraft) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHead("Choose a background", subtitle: "Pick a card, then tune the crop and readability.", icon: "rectangle.stack.fill")
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(TemplateCategory.allCases) { category in
                        let count = CardTemplates.all.filter { $0.category == category }.count
                        Button {
                            templateCategory = category
                            FeedbackCenter.selectionChanged()
                        } label: {
                            HStack(spacing: 6) {
                                Text(category.label)
                                Text("\(count)")
                                    .foregroundStyle(templateCategory == category ? .white.opacity(0.64) : Tokens.muted2)
                            }
                            .font(AppFont.outfit(11.5, weight: .bold, relativeTo: .caption))
                            .foregroundStyle(templateCategory == category ? .white : Tokens.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 40)
                            .background(templateCategory == category ? Tokens.ink : Tokens.sand1, in: Capsule())
                        }
                        .buttonStyle(PesolitaPressStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -22)
            .contentMargins(.horizontal, 22, for: .scrollContent)

            CardTemplatePickerView(
                category: templateCategory,
                selectedID: selectedTemplate?.id,
                onSelect: store.applyTemplate
            )
            .id(templateCategory)
            .padding(.horizontal, -22)
            photoTuning(draft.card.art)
        }
    }

    private func diyControls(_ draft: CardEditorDraft) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                sectionHead("Make it yourself", subtitle: "Choose a generated style or use a photo.", icon: "paintpalette.fill")
                Spacer()
                Button { store.randomizeEditorArt() } label: {
                    Label("Surprise me", systemImage: "dice.fill")
                        .font(AppFont.outfit(11.5, weight: .bold, relativeTo: .caption))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        .background(Tokens.sand1, in: Capsule())
                }
                .buttonStyle(PesolitaPressStyle())
            }

            editorGroup("ARTWORK") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                    ForEach(CardArtStyle.allCases.filter { $0 != .photo }, id: \.self) { style in
                        Button {
                            store.updateEditorArt { art in
                                art.style = style
                                art.photo = nil
                            }
                            FeedbackCenter.selectionChanged()
                        } label: {
                            VStack(spacing: 7) {
                                CardArtView(art: previewArt(style), cornerRadius: 9)
                                    .frame(height: 46)
                                Text(styleName(style))
                                    .font(AppFont.outfit(10.5, weight: .bold, relativeTo: .caption2))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Tokens.ink)
                            .padding(6)
                            .background(draft.card.art.style == style ? Tokens.bluePale : Tokens.sand1, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(draft.card.art.style == style ? Tokens.blue : .clear, lineWidth: 2))
                        }
                        .buttonStyle(PesolitaPressStyle())
                    }
                }
                PhotosPicker(selection: $artworkPhoto, matching: .images) {
                    Label(draft.card.art.style == .photo ? "Replace personal photo" : "Use a personal photo", systemImage: "photo.on.rectangle.angled")
                        .font(AppFont.outfit(12.5, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Tokens.ink)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Tokens.sand1, in: Capsule())
                }
                if draft.card.art.style == .glyph {
                    textField("Big background letter", text: artGlyphBinding, icon: "textformat")
                }
            }

            editorGroup("COLORS & FINISH") {
                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        ForEach(Array(paletteValues.enumerated()), id: \.offset) { _, palette in
                            Button {
                                store.updateEditorArt { art in art.c1 = palette.0; art.c2 = palette.1 }
                                FeedbackCenter.selectionChanged()
                            } label: {
                                ZStack {
                                    Circle().fill(Color(hex: palette.0)).offset(x: -7)
                                    Circle().fill(Color(hex: palette.1)).offset(x: 7)
                                }
                                .frame(width: 52, height: 44)
                                .overlay(Capsule().stroke(draft.card.art.c1 == palette.0 && draft.card.art.c2 == palette.1 ? Tokens.ink : Tokens.line3, lineWidth: 2))
                            }
                            .buttonStyle(PesolitaPressStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)

                HStack(spacing: 7) {
                    ForEach(CardTexture.allCases, id: \.self) { texture in
                        optionPill(texture.rawValue.capitalized, selected: draft.card.art.tex == texture) {
                            store.updateEditorArt { $0.tex = texture }
                        }
                    }
                }
            }

            if draft.card.art.style == .photo { photoTuning(draft.card.art) }
            else { readabilityControls(draft.card.art) }
        }
    }

    private func photoTuning(_ art: CardArt) -> some View {
        editorGroup("POSITION & READABILITY") {
            if art.photo != nil {
                labeledSlider("Zoom", value: photoBinding(\.zoom), range: 1...2.4, icon: "plus.magnifyingglass")
                labeledSlider("Horizontal", value: photoBinding(\.px), range: -40...40, icon: "arrow.left.and.right")
                labeledSlider("Vertical", value: photoBinding(\.py), range: -40...40, icon: "arrow.up.and.down")
                HStack(spacing: 7) {
                    optionPill("Soft blur", selected: art.photo?.blur == true) {
                        store.updateEditorArt { $0.photo?.blur.toggle() }
                    }
                    optionPill("Reset crop", selected: false) {
                        store.updateEditorArt { art in
                            art.photo?.zoom = 1
                            art.photo?.px = 0
                            art.photo?.py = 0
                        }
                    }
                }
                readabilityControls(art)
            }
        }
    }

    private func readabilityControls(_ art: CardArt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text color")
                .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Tokens.muted1)
            HStack(spacing: 7) {
                ForEach(TextMode.allCases, id: \.self) { mode in
                    optionPill(mode.rawValue.capitalized, selected: (art.photo?.textMode ?? .auto) == mode) {
                        store.updateEditorArt { $0.photo?.textMode = mode }
                    }
                }
            }
            Text("Readability overlay")
                .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Tokens.muted1)
            HStack(spacing: 7) {
                ForEach(ScrimKey.allCases, id: \.self) { scrim in
                    optionPill(scrim.rawValue.capitalized, selected: (art.photo?.scrim ?? .off) == scrim) {
                        store.updateEditorArt { $0.photo?.scrim = scrim }
                    }
                }
            }
            Button {
                store.updateEditorArt { art in
                    guard var photo = art.photo else { return }
                    photo.textMode = photo.sample.relativeLuminance > 0.43 ? .dark : .light
                    photo.scrim = .soft
                    art.photo = photo
                }
                FeedbackCenter.snap()
            } label: {
                Label("Auto-fix contrast", systemImage: "wand.and.stars")
                    .font(AppFont.outfit(12, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Tokens.blueDeep)
                    .frame(maxWidth: .infinity, minHeight: 43)
                    .background(Tokens.bluePale, in: Capsule())
            }
            .buttonStyle(PesolitaPressStyle())
        }
    }

    private func detailsControls(_ draft: CardEditorDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(Tokens.easeSpring(0.28)) { detailsExpanded.toggle() }
                FeedbackCenter.tap()
            } label: {
                HStack {
                    sectionHead("Card details", subtitle: "Name, balance, chip and receiving info.", icon: "creditcard.fill")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(detailsExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if detailsExpanded {
                VStack(spacing: 14) {
                    textField("Card nickname", text: cardStringBinding(\.nick), icon: "tag.fill")
                    HStack(spacing: 10) {
                        numberField("Balance", value: cardDoubleBinding(\.bal), icon: "pesosign")
                        numberField("Monthly limit", value: cardDoubleBinding(\.limit), icon: "gauge")
                    }
                    Picker("Card kind", selection: cardKindBinding) {
                        ForEach(CardKind.allCases) { kind in Text(kind.label).tag(kind) }
                    }
                    .font(AppFont.outfit(13.5, weight: .bold, relativeTo: .subheadline))
                    .padding(.horizontal, 13)
                    .frame(minHeight: 48)
                    .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    HStack(spacing: 10) {
                        textField("Last 4", text: cardStringBinding(\.last4), icon: "number")
                        textField("Expiry", text: cardStringBinding(\.exp), icon: "calendar")
                    }

                    if draft.card.kind == .savings || draft.card.kind == .emergency {
                        numberField("Savings goal", value: optionalCardDoubleBinding(\.goal), icon: "target")
                    }

                    HStack(spacing: 8) {
                        optionPill("Chip", selected: draft.card.art.chip) {
                            store.updateEditorArt { $0.chip.toggle() }
                        }
                        ForEach(["Gold", "Platinum", "Black"], id: \.self) { tier in
                            optionPill(tier, selected: draft.card.art.tier == tier.lowercased()) {
                                store.updateEditorArt { art in
                                    art.tier = art.tier == tier.lowercased() ? nil : tier.lowercased()
                                }
                            }
                        }
                    }

                    textField("Account / receiving number", text: optionalCardStringBinding(\.accountNumber), icon: "number.square.fill")
                    PhotosPicker(selection: $qrPhoto, matching: .images) {
                        HStack {
                            Label(draft.card.qr == nil ? "Add receiving QR" : "Replace receiving QR", systemImage: "qrcode")
                            Spacer()
                            if draft.card.qr != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.green) }
                        }
                        .font(AppFont.outfit(12.5, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(Tokens.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(Tokens.sand1.opacity(0.70), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func saveControls(_ draft: CardEditorDraft) -> some View {
        VStack(spacing: 11) {
            Button { store.saveEditorCard() } label: {
                Text(draft.isNew ? "Add this card" : "Save redesign")
                    .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 55)
                    .background(Tokens.ink, in: Capsule())
            }
            .buttonStyle(PesolitaPressStyle())
            if !draft.isNew {
                Button(role: .destructive) { store.requestDeleteEditorCard() } label: {
                    Label("Delete this card", systemImage: "trash")
                        .font(AppFont.outfit(13, weight: .bold, relativeTo: .subheadline))
                }
            }
        }
    }

    private func modeButton(_ mode: EditorMode, icon: String, label: String) -> some View {
        let selected = draft?.mode == mode
        return Button { store.setEditorMode(mode) } label: {
            Label(label, systemImage: icon)
                .font(AppFont.outfit(12.5, weight: .bold, relativeTo: .caption))
                .foregroundStyle(selected ? Tokens.ink : .white.opacity(0.55))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? .white : Tokens.dark2, in: Capsule())
        }
        .buttonStyle(PesolitaPressStyle())
    }

    private func sectionHead(_ title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(AppFont.outfit(20, weight: .black, relativeTo: .title3))
            Text(subtitle)
                .font(AppFont.outfit(12, relativeTo: .caption))
                .foregroundStyle(Tokens.muted2)
        }
    }

    private func editorGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(AppFont.outfit(10, weight: .semibold, relativeTo: .caption2))
                .tracking(1.2)
                .foregroundStyle(Tokens.muted2)
            content()
        }
        .padding(16)
        .background(Tokens.sand1.opacity(0.7), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private func optionPill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.outfit(11, weight: .bold, relativeTo: .caption))
                .foregroundStyle(selected ? .white : Tokens.ink)
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(selected ? Tokens.ink : .white, in: Capsule())
                .overlay(Capsule().stroke(selected ? .clear : Tokens.line3))
        }
        .buttonStyle(PesolitaPressStyle())
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
            }
            .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(Tokens.muted1)
            Slider(value: value, in: range)
                .tint(Tokens.ink)
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(Tokens.muted3)
            TextField(placeholder, text: text)
                .font(AppFont.outfit(13.5, weight: .medium, relativeTo: .body))
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 48)
        .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func numberField(_ placeholder: String, value: Binding<Double>, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).foregroundStyle(Tokens.muted3)
            TextField(placeholder, value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(AppFont.outfit(13, weight: .medium, relativeTo: .body))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func previewArt(_ style: CardArtStyle) -> CardArt {
        var art = draft?.card.art ?? .cash
        art.style = style
        art.photo = nil
        return art
    }

    private func styleName(_ style: CardArtStyle) -> String {
        switch style {
        case .irid: "Iridescent"
        default: style.rawValue.capitalized
        }
    }

    private var paletteValues: [(String, String)] {
        [("#ffca28", "#0b0b0c"), ("#1d6ff2", "#f4eedc"), ("#f4eedc", "#f0483e"),
         ("#f9a8b4", "#f0483e"), ("#16161a", "#ffca28"), ("#0b8f6a", "#f4eedc"),
         ("#7c3aed", "#f9a8b4"), ("#f0483e", "#ffca28")]
    }

    private func cardStringBinding(_ path: WritableKeyPath<Card, String>) -> Binding<String> {
        Binding(get: { draft?.card[keyPath: path] ?? "" }, set: { value in store.updateEditorCard { $0[keyPath: path] = value } })
    }

    private func optionalCardStringBinding(_ path: WritableKeyPath<Card, String?>) -> Binding<String> {
        Binding(get: { draft?.card[keyPath: path] ?? "" }, set: { value in store.updateEditorCard { $0[keyPath: path] = value } })
    }

    private func cardDoubleBinding(_ path: WritableKeyPath<Card, Double>) -> Binding<Double> {
        Binding(get: { draft?.card[keyPath: path] ?? 0 }, set: { value in store.updateEditorCard { $0[keyPath: path] = value } })
    }

    private var cardKindBinding: Binding<CardKind> {
        Binding(get: { draft?.card.kind ?? .debit }, set: { value in store.updateEditorCard { $0.kind = value } })
    }

    private var artGlyphBinding: Binding<String> {
        Binding(
            get: { draft?.card.art.glyph ?? "" },
            set: { value in store.updateEditorArt { $0.glyph = String(value.prefix(2)) } }
        )
    }

    private func optionalCardDoubleBinding(_ path: WritableKeyPath<Card, Double?>) -> Binding<Double> {
        Binding(
            get: { draft?.card[keyPath: path] ?? 0 },
            set: { value in store.updateEditorCard { $0[keyPath: path] = value > 0 ? value : nil } }
        )
    }

    private func photoBinding(_ path: WritableKeyPath<PhotoArt, Double>) -> Binding<Double> {
        Binding(
            get: { draft?.card.art.photo?[keyPath: path] ?? 0 },
            set: { value in store.updateEditorArt { $0.photo?[keyPath: path] = value } }
        )
    }

    private func importPhoto(_ item: PhotosPickerItem?, qr: Bool) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await store.attachEditorImage(data, asQR: qr)
            } else {
                store.showToast("Could not use that image.")
            }
        }
    }
}
