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

    var body: some View {
        let debts = store.debts
        if !debts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("OUT WITH FRIENDS")
                        .font(AppFont.outfit(10, weight: .bold))
                        .kerning(1.3)
                        .foregroundStyle(Tokens.accentText)
                    Text("₱\(MoneyFormat.amount(store.totalOwed))")
                        .font(AppFont.outfit(30, weight: .bold))
                        .foregroundStyle(Tokens.text)
                        .monospacedDigit()
                        .padding(.top, 6)
                    Text(subtitle(for: debts))
                        .font(AppFont.outfit(12, weight: .medium))
                        .foregroundStyle(Tokens.muted3)
                        .padding(.top, 2)
                }

                VStack(spacing: 7) {
                    ForEach(debts.prefix(visible)) { debt in
                        row(for: debt)
                    }
                }

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
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 16)
            .background(Tokens.dark2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Money out with friends")
            .sheet(item: $sharing) { ActivityShareSheet(text: $0.text) }
        }
    }

    private func subtitle(for debts: [PersonDebt]) -> String {
        let people = debts.count == 1 ? "1 person" : "\(debts.count) people"
        let events = Set(debts.compactMap(\.lastEventId))
        guard !events.isEmpty else { return people }
        return "\(people) · \(events.count == 1 ? "1 event" : "\(events.count) events")"
    }

    private func row(for debt: PersonDebt) -> some View {
        HStack(spacing: 9) {
            Group {
                if let src = debt.photoSrc, let url = store.mediaStore.url(for: src), let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    Text(SplitMath.initial(debt.name))
                        .font(AppFont.outfit(12, weight: .bold))
                        .foregroundStyle(Tokens.on(hex: debt.color))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: debt.color), in: Circle())
                }
            }

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

            Button("Paid me") { store.askSettle(personID: debt.personId) }
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
