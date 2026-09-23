import SwiftUI

/// Every trip and night out the wallet has grouped.
///
/// An event is a lens on spends that already exist, so this screen is reached from Insights
/// and from the spend sheet rather than from the tab bar.
struct EventsView: View {
    @Bindable var store: WalletStore
    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        let events = EventMetrics.sorted(store.snapshot.events)
        let running = events.first { $0.endedAt == nil }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SocialHeader(
                    title: running.map { "\($0.emoji) \($0.name)" } ?? "Trips and nights out",
                    subtitle: running != nil
                        ? "Running now — new spends land in it automatically."
                        : "Group a run of spends so you can see what the whole thing cost."
                )

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Start an event")
                            .font(AppFont.outfit(15, weight: .bold))
                            .foregroundStyle(Tokens.text)
                        HStack(spacing: 8) {
                            TextField("Day 1 Thailand", text: $draftName)
                                .font(AppFont.outfit(13.5, weight: .medium))
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .onSubmit(start)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Tokens.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Tokens.line4, lineWidth: 1.5)
                                )
                            Button("Start", action: start)
                                .font(AppFont.outfit(13, weight: .bold))
                                .foregroundStyle(draftName.trimmed.isEmpty ? Tokens.muted3 : Tokens.background)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(draftName.trimmed.isEmpty ? Tokens.dark3 : Tokens.text,
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .buttonStyle(.plain)
                                .disabled(draftName.trimmed.isEmpty)
                        }
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        Text(events.isEmpty ? "Nothing grouped yet" : "All events")
                            .font(AppFont.outfit(15, weight: .bold))
                            .foregroundStyle(Tokens.text)

                        if events.isEmpty {
                            SocialEmptyState(
                                title: "No events yet",
                                message: "Start one before a trip and every spend you log lands inside it, so the total is already waiting when you get home."
                            )
                        } else {
                            VStack(spacing: 8) {
                                ForEach(events) { event in
                                    row(for: event)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .background(Tokens.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        // The bar shares the page colour so it reads as part of the hero, in either mode.
        .toolbarBackground(Tokens.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func start() {
        guard !draftName.trimmed.isEmpty else { return }
        store.createEvent(draftName)
        draftName = ""
        nameFocused = false
    }

    private func row(for event: EventGroup) -> some View {
        let totals = EventMetrics.totals(store.snapshot.tx, eventID: event.id)
        return Button {
            store.openEventDetail(event.id)
        } label: {
            HStack(spacing: 11) {
                Text(event.emoji)
                    .font(.system(size: 16))
                    .frame(width: 34, height: 34)
                    .background(Tokens.dark3, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(AppFont.outfit(13.5, weight: .semibold))
                        .foregroundStyle(Tokens.text)
                        .lineLimit(1)
                    Text(EventMetrics.dateLabel(event)
                         + (totals.count > 0 ? " · \(totals.count == 1 ? "1 spend" : "\(totals.count) spends")" : ""))
                        .font(AppFont.outfit(11.5, weight: .medium))
                        .foregroundStyle(Tokens.muted2)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("₱\(MoneyFormat.amount(totals.total))")
                        .font(AppFont.outfit(14, weight: .bold))
                        .foregroundStyle(Tokens.text)
                        .monospacedDigit()
                    if totals.owed > 0 {
                        Text("₱\(MoneyFormat.amount(totals.owed)) owed")
                            .font(AppFont.outfit(10.5, weight: .medium))
                            .foregroundStyle(Tokens.muted2)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(Tokens.dark1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PesolitaPressStyle())
    }
}
