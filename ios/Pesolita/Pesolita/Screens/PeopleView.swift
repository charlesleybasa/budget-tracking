import SwiftUI
import PhotosUI

/// Everyone the wallet splits with, and what they still owe.
///
/// Reached from the owed strip and from Settings — not from the tab bar, which stays at four
/// destinations. Overcrowded navigation is one of the loudest complaints about the app this
/// feature is answering.
struct PeopleView: View {
    @Bindable var store: WalletStore
    @State private var draftName = ""
    @State private var sharing: SharePayload?
    @FocusState private var nameFocused: Bool
    @State private var expandedPeople: Set<String> = []
    
    @State private var attachingPhotoToPerson: Person?    
    @State private var editingPersonID: String?
    @State private var editingDraftName = ""
    @State private var personToRemove: Person?

    private var roster: [Person] { store.snapshot.people.filter { !$0.archived } }

    @State private var selectedFilter: SocialFilterTab = .people

    enum SocialFilterTab: String, CaseIterable {
        case people = "People"
        case events = "Events"
        case categories = "Categories"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(SocialFilterTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Tokens.background)

            if selectedFilter == .people {
                peopleTab
            } else if selectedFilter == .events {
                EventsView(store: store)
            } else {
                categoriesTab
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Tokens.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $sharing) { ActivityShareSheet(text: $0.text) }
        .alert("Edit Name", isPresented: Binding(
            get: { editingPersonID != nil },
            set: { if !$0 { editingPersonID = nil } }
        )) {
            TextField("Name", text: $editingDraftName)
            Button("Cancel", role: .cancel) { editingPersonID = nil }
            Button("Save") {
                if let id = editingPersonID {
                    store.updatePerson(id, newName: editingDraftName)
                }
                editingPersonID = nil
            }
        }
        .alert("Remove \(personToRemove?.name ?? "person")?", isPresented: Binding(
            get: { personToRemove != nil },
            set: { if !$0 { personToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) { personToRemove = nil }
            Button("Remove", role: .destructive) {
                if let id = personToRemove?.id {
                    store.deletePerson(id)
                }
                personToRemove = nil
            }
        } message: {
            Text("They will be removed from this list, but your past splits will keep their name.")
        }
        .fullScreenCover(item: $attachingPhotoToPerson) { person in
            ImagePicker { data in
                Task {
                    await store.attachPersonPhoto(personId: person.id, data: data)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var peopleTab: some View {
        let debts = store.debts
        let owedBy = Dictionary(uniqueKeysWithValues: debts.map { ($0.personId, $0) })
        let total = store.totalOwed

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SocialHeader(
                    title: total > 0 ? "₱\(MoneyFormat.amount(total)) is out there" : "Nobody owes you",
                    subtitle: total > 0
                        ? "Tap paid when it lands. It tops up the card it came out of."
                        : "Split a spend and whoever owes you shows up here."
                )

                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Add someone")
                            .font(AppFont.outfit(15, weight: .bold))
                            .foregroundStyle(Tokens.text)
                        HStack(spacing: 8) {
                            TextField("Their name", text: $draftName)
                                .font(AppFont.outfit(13.5, weight: .medium))
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .onSubmit(add)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Tokens.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Tokens.line4, lineWidth: 1.5)
                                )
                            Button("Add", action: add)
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
                        Text(roster.isEmpty
                             ? "Nobody yet"
                             : (roster.count == 1 ? "1 person" : "\(roster.count) people"))
                            .font(AppFont.outfit(15, weight: .bold))
                            .foregroundStyle(Tokens.text)

                        if roster.isEmpty {
                            SocialEmptyState(
                                title: "No one here yet",
                                message: "Add the people you actually split with — housemates, the usual barkada — and they will be one tap away inside the spend sheet."
                            )
                        } else {
                            VStack(spacing: 8) {
                                ForEach(roster) { person in
                                    row(person: person, debt: owedBy[person.id])
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
    }
    
    private var categoriesTab: some View {
        let totals = WalletMetrics.categoryTotals(store.snapshot.tx, period: .all)
        let maxAmount = totals.map(\.amount).max() ?? 1
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SocialHeader(
                    title: "Categories",
                    subtitle: "See where your money goes by category."
                )
                
                VStack(spacing: 12) {
                    ForEach(totals) { total in
                        Button { 
                            store.searchQuery = total.category.rawValue
                            store.selectedTab = .search
                            store.path = []
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 7) {
                                    Circle().fill(Color(hex: total.category.colorHex)).frame(width: 9, height: 9)
                                    Text(total.category.rawValue).font(AppFont.outfit(13, weight: .semibold, relativeTo: .subheadline))
                                    Spacer()
                                    Text("₱\(MoneyFormat.amount(total.amount))")
                                        .font(AppFont.outfit(12.5, weight: .semibold, relativeTo: .caption))
                                        .foregroundStyle(Tokens.text)
                                }
                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Tokens.dark1).frame(maxWidth: .infinity, maxHeight: .infinity)
                                        Capsule().fill(Color(hex: total.category.colorHex)).frame(width: proxy.size.width * total.amount / maxAmount)
                                    }
                                }
                                .frame(height: 5)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Tokens.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Tokens.line4, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .background(Tokens.background)
        .scrollIndicators(.hidden)
    }

    private func add() {
        guard !draftName.trimmed.isEmpty else { return }
        store.addPerson(draftName)
        draftName = ""
        nameFocused = false
    }

    private func row(person: Person, debt: PersonDebt?) -> some View {
        let isExpanded = expandedPeople.contains(person.id)
        
        return VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button {
                    attachingPhotoToPerson = person
                } label: {
                    if let src = person.photoSrc, let url = store.mediaStore.url(for: src), let uiImage = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                    } else {
                        Text(SplitMath.initial(person.name))
                            .font(AppFont.outfit(13, weight: .bold))
                            .foregroundStyle(Tokens.on(hex: person.color))
                            .frame(width: 34, height: 34)
                            .background(Color(hex: person.color), in: Circle())
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Button {
                            editingDraftName = person.name
                            editingPersonID = person.id
                        } label: {
                            Text(person.name)
                                .font(AppFont.outfit(13.5, weight: .semibold))
                                .foregroundStyle(Tokens.text)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        if let debt = debt, debt.count > 1 {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Tokens.muted2)
                        }
                    }
                    Text(subtitle(for: debt))
                        .font(AppFont.outfit(11.5, weight: .medium))
                        .foregroundStyle(Tokens.muted2)
                        .lineLimit(1)
                }
                .layoutPriority(0)

                Spacer(minLength: 4)

                if let debt {
                    Text("₱\(MoneyFormat.amount(debt.amount))")
                        .font(AppFont.outfit(14, weight: .bold))
                        .foregroundStyle(Tokens.text)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)

                    Button {
                        sharing = SharePayload(text: SplitMath.reminder(for: debt, ownerName: store.snapshot.userName))
                    } label: {
                        Image(systemName: "paperplane")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.muted1)
                            .frame(width: 34, height: 34)
                            .background(Tokens.dark3, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send \(person.name) a reminder")

                    Button("Paid me") { store.askSettle(personID: person.id) }
                        .font(AppFont.outfit(11.5, weight: .bold))
                        .foregroundStyle(Tokens.onAccent)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                        .background(Tokens.accent, in: Capsule())
                        .buttonStyle(.plain)
                        .fixedSize()
                } else {
                    Button("Remove") { personToRemove = person }
                        .font(AppFont.outfit(11.5, weight: .bold))
                        .foregroundStyle(Tokens.negative)
                        .frame(minHeight: 34)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let debt = debt, debt.count > 1 else { return }
                withAnimation(.snappy) {
                    if isExpanded { expandedPeople.remove(person.id) }
                    else { expandedPeople.insert(person.id) }
                }
            }
            
            if let debt = debt, isExpanded, debt.count > 1 {
                VStack(spacing: 8) {
                    ForEach(debt.unsettledSpends) { spend in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(spend.transaction.note.trimmingCharacters(in: .whitespaces).isEmpty ? spend.transaction.cat.rawValue : spend.transaction.note)
                                    .font(AppFont.outfit(13, weight: .semibold))
                                    .foregroundStyle(Tokens.text)
                                    .lineLimit(1)
                                Text(Date(timeIntervalSince1970: spend.transaction.at).formatted(.dateTime.month().day()))
                                    .font(AppFont.outfit(11, weight: .medium))
                                    .foregroundStyle(Tokens.muted2)
                            }
                            Spacer()
                            Text("₱\(MoneyFormat.amount(spend.owedAmount))")
                                .font(AppFont.outfit(13, weight: .bold))
                                .foregroundStyle(Tokens.text)
                            Button("Settle") { store.askSettle(personID: person.id, transactionID: spend.transaction.id) }
                                .font(AppFont.outfit(11, weight: .bold))
                                .foregroundStyle(Tokens.text)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 28)
                                .background(Tokens.background, in: Capsule())
                                .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Tokens.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Tokens.dark1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func subtitle(for debt: PersonDebt?) -> String {
        guard let debt else { return "All settled up" }
        let spends = debt.count == 1 ? "1 spend" : "\(debt.count) spends"
        guard let event = EventMetrics.find(store.snapshot.events, id: debt.lastEventId) else { return spends }
        return "\(spends) · \(event.name)"
    }
}

// MARK: - Shared chrome

/// The dark hero these three screens share. Matches the Insights header so the split screens
/// read as part of the same app rather than as a bolted-on section.
struct SocialHeader: View {
    var emoji: String?
    var title: String
    var subtitle: String
    var stats: [(String, String, Bool)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let emoji {
                Text(emoji).font(.system(size: 22))
            }
            Text(title)
                .font(AppFont.outfit(27, weight: .bold))
                .foregroundStyle(Tokens.text)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.top, emoji == nil ? 0 : 6)
            Text(subtitle)
                .font(AppFont.outfit(12, weight: .medium))
                .foregroundStyle(Tokens.muted3)
                .padding(.top, 4)

            if !stats.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stat.0.uppercased())
                                .font(AppFont.outfit(9.5, weight: .bold))
                                .kerning(1.05)
                                .foregroundStyle(Tokens.muted2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(stat.1)
                                .font(AppFont.outfit(19, weight: .bold))
                                .foregroundStyle(stat.2 ? Tokens.accentText : Tokens.paper)
                                .monospacedDigit()
                                // A peso figure that wraps mid-number reads as two numbers.
                                // Shrink to fit instead, down to the point it stays legible.
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Tokens.darkHover, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(
            Tokens.background,
            in: UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26, style: .continuous)
        )
    }
}

struct SocialEmptyState: View {
    var title: String
    /// Named `message` rather than `body`, which the View protocol already claims.
    var message: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(AppFont.outfit(16, weight: .bold))
                .foregroundStyle(Tokens.text)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppFont.outfit(13, weight: .regular))
                .foregroundStyle(Tokens.muted1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
}
