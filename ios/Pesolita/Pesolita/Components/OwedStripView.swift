import SwiftUI
import UIKit

/// Money that is out with other people.
///
/// One direction only — there is no "you owe them" side to this ledger, which is why there is
/// nothing here to simplify and no debt graph to read. Tapping "Paid me" is not bookkeeping:
/// it tops up a real card, because the money really did come back.
///
/// Renders nothing at all when nobody owes anything, the same way the notices beside it are
/// derived from the wallet rather than seeded.
struct OwedStripView: View {
    @Bindable var store: WalletStore
    /// Rows shown before the strip defers to the full people screen.
    private let visible = 4
    @State private var sharing: SharePayload?
    /// Home stays calm: one summary row until the user asks to see who owes what.
    @AppStorage("home.owedExpanded") private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let debts = store.debts
        if !debts.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                summary(debts)

                if expanded {
                    VStack(spacing: 7) {
                        ForEach(debts.prefix(visible)) { debt in
                            row(for: debt)
                        }
                    }
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    HStack {
                        Text(debts.count > visible
                             ? "\(debts.count - visible) more waiting"
                             : "Lands back in the card it came out of.")
                            .font(AppFont.outfit(10.5, weight: .medium))
                            .foregroundStyle(Tokens.muted2)
                        Spacer(minLength: 8)
                        Button("See everyone") { store.path.append(.people) }
                            .font(AppFont.outfit(11.5, weight: .semibold))
                            .foregroundStyle(Tokens.accentText)
                            .buttonStyle(.plain)
                            .frame(minHeight: 32)
                    }
                    .padding(.top, 10)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, expanded ? 14 : 10)
            .background(Tokens.dark2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Tokens.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Money out with friends")
            .sheet(item: $sharing) { ActivityShareSheet(text: $0.text) }
        }
    }

    /// The always-visible row: who, how much, and a chevron that says there is more.
    private func summary(_ debts: [PersonDebt]) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
                expanded.toggle()
            }
            FeedbackCenter.selectionChanged()
        } label: {
            HStack(spacing: 12) {
                avatarStack(debts)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OUT WITH FRIENDS")
                        .font(AppFont.outfit(9.5, weight: .bold))
                        .kerning(1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Tokens.accentText)
                    // Where there's no room for "from 4 people", the faces already say it —
                    // show the amount alone rather than a clipped "from 4 p…".
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            owedAmount
                            Text(debts.count == 1 ? "from 1 person" : "from \(debts.count) people")
                                .font(AppFont.outfit(11.5, weight: .medium))
                                .foregroundStyle(Tokens.muted3)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        owedAmount
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.muted1)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .frame(width: 32, height: 32)
                    .background(Tokens.darkHover, in: Circle())
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PesolitaPressStyle())
        .accessibilityLabel("Out with friends, ₱\(MoneyFormat.amount(store.totalOwed)), \(subtitle(for: debts))")
        .accessibilityHint(expanded ? "Hides the list" : "Shows who owes you")
        .accessibilityAddTraits(.isButton)
    }

    private var owedAmount: some View {
        Text("₱\(MoneyFormat.amount(store.totalOwed))")
            .font(AppFont.outfit(19, weight: .bold, relativeTo: .headline))
            .foregroundStyle(Tokens.text)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .contentTransition(.numericText())
    }

    /// Up to three faces, overlapping, so the row reads as "these people" at a glance.
    private func avatarStack(_ debts: [PersonDebt]) -> some View {
        let shown = Array(debts.prefix(3))
        return HStack(spacing: -10) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, debt in
                avatar(for: debt, size: 32)
                    .overlay(Circle().strokeBorder(Tokens.dark2, lineWidth: 2.5))
                    .zIndex(Double(shown.count - index))
            }
            if debts.count > 3 {
                Text("+\(debts.count - 3)")
                    .font(AppFont.outfit(10.5, weight: .bold))
                    .foregroundStyle(Tokens.text)
                    .frame(width: 32, height: 32)
                    .background(Tokens.darkHover, in: Circle())
                    .overlay(Circle().strokeBorder(Tokens.dark2, lineWidth: 2.5))
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func avatar(for debt: PersonDebt, size: CGFloat) -> some View {
        if let src = debt.photoSrc, let url = store.mediaStore.url(for: src), let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(SplitMath.initial(debt.name))
                .font(AppFont.outfit(size * 0.42, weight: .bold))
                .foregroundStyle(Tokens.on(hex: debt.color))
                .frame(width: size, height: size)
                .background(Color(hex: debt.color), in: Circle())
        }
    }

    private func subtitle(for debts: [PersonDebt]) -> String {
        let people = debts.count == 1 ? "1 person" : "\(debts.count) people"
        let events = Set(debts.compactMap(\.lastEventId))
        guard !events.isEmpty else { return people }
        return "\(people) · \(events.count == 1 ? "1 event" : "\(events.count) events")"
    }

    /// In a narrow pane (iPhone Duo unfolded, portrait) the reminder button gives way so the
    /// person's name still shows; reminders stay a tap away on the People screen.
    private func row(for debt: PersonDebt) -> some View {
        ViewThatFits(in: .horizontal) {
            rowContent(for: debt, showsReminder: true)
            rowContent(for: debt, showsReminder: false)
        }
    }

    private func rowContent(for debt: PersonDebt, showsReminder: Bool) -> some View {
        HStack(spacing: 9) {
            avatar(for: debt, size: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(debt.name)
                    .font(AppFont.outfit(13, weight: .semibold))
                    .foregroundStyle(Tokens.text)
                    .lineLimit(1)
                Text(where_(for: debt))
                    .font(AppFont.outfit(10.5, weight: .medium))
                    .foregroundStyle(Tokens.muted2)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text("₱\(MoneyFormat.amount(debt.amount))")
                .font(AppFont.outfit(13, weight: .bold))
                .foregroundStyle(Tokens.text)
                .monospacedDigit()
                // Amounts and the button never wrap; the name gives way instead.
                .lineLimit(1)
                .fixedSize()

            if showsReminder {
                Button {
                    sharing = SharePayload(text: SplitMath.reminder(for: debt, ownerName: store.snapshot.userName))
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.muted3)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(Tokens.darkHover, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send \(debt.name) a reminder")
            }

            Button("Paid me") { store.askSettle(personID: debt.personId) }
                .lineLimit(1)
                .fixedSize()
                .font(AppFont.outfit(11, weight: .bold))
                .foregroundStyle(Tokens.onAccent)
                .padding(.horizontal, 11)
                .frame(minHeight: 32)
                .background(Tokens.accent, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Tokens.darkHover, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func where_(for debt: PersonDebt) -> String {
        let spends = debt.count == 1 ? "1 spend" : "\(debt.count) spends"
        guard let event = EventMetrics.find(store.snapshot.events, id: debt.lastEventId) else { return spends }
        return "\(event.name) · \(spends)"
    }
}

/// Wraps a string so `.sheet(item:)` can carry it — the share sheet is the whole "sharing"
/// story here, and the app still makes no network call of its own.
struct SharePayload: Identifiable {
    let id = UUID()
    let text: String
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
