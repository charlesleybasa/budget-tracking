import SwiftUI

struct CardTemplatePickerView: View {
    var category: TemplateCategory
    var selectedID: String?
    /// The onboarding panel is dark; the card editor's is white.
    var onDark = false
    var onSelect: (CardTemplate) -> Void

    @State private var focusedID: String?

    private var templates: [CardTemplate] {
        CardTemplates.all.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(templates) { template in
                        Button {
                            focusedID = template.id
                            onSelect(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CardArtView(art: template.art, cornerRadius: 17)
                                    .frame(width: 252)
                                    .overlay(alignment: .topTrailing) {
                                        if template.id == selectedID {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(onDark ? Tokens.ink : .white)
                                                .frame(width: 34, height: 34)
                                                .background(onDark ? Color.white : Tokens.ink, in: Circle())
                                                .padding(10)
                                        }
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                                            .stroke(template.id == selectedID ? (onDark ? Color.white : Tokens.ink) : Color.clear, lineWidth: 3)
                                    }
                                Text(template.name)
                                    .font(AppFont.outfit(14, weight: .bold, relativeTo: .subheadline))
                                    .foregroundStyle(onDark ? .white : Tokens.ink)
                                    .lineLimit(1)
                            }
                            .frame(width: 252, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .id(template.id)
                        .scrollTransition(.animated.threshold(.visible(0.55))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.90)
                                .rotation3DEffect(.degrees(phase.value * -7), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
                                .opacity(phase.isIdentity ? 1 : 0.74)
                        }
                        .accessibilityLabel("\(template.name), \(template.category.label)")
                        .accessibilityAddTraits(template.id == selectedID ? .isSelected : [])
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            // Height the cards actually need: 252pt wide at the card aspect, plus the label.
            .frame(height: 252 * (Tokens.cardH / Tokens.cardW) + 30)
            .scrollPosition(id: $focusedID, anchor: .center)
            .onChange(of: focusedID) { _, id in
                guard let id, let template = templates.first(where: { $0.id == id }) else { return }
                onSelect(template)
            }

            Text("Swipe or tap a card")
                .font(AppFont.outfit(11, weight: .medium, relativeTo: .caption))
                .foregroundStyle(onDark ? .white.opacity(0.42) : Tokens.muted2)
        }
        .onAppear { focusedID = selectedID ?? templates.first?.id }
    }
}

