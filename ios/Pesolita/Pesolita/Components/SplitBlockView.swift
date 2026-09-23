import SwiftUI

/// The split row in the transaction sheet.
///
/// Collapsed to a single "Just me" row until it is opened, because splitting is one tap
/// deeper than logging rather than a flow of its own — the complaint people make about
/// Splitwise is that adding an expense costs several screens every single time.
struct SplitBlockView: View {
    @Bindable var store: WalletStore
    @State private var isOpen = Self.startsOpen
    /// Store screenshots show the split opened, so the people and shares are visible.
    private static var startsOpen: Bool {
        #if DEBUG
        StoreCapture.active && ProcessInfo.processInfo.arguments.contains("--split-open")
        #else
        false
        #endif
    }
    @State private var addingPerson = false
    @State private var draftName = ""
    @State private var addingEvent = false
    @State private var draftEventName = ""
    @FocusState private var nameFocused: Bool
    @FocusState private var eventFocused: Bool

    private var roster: [Person] { store.snapshot.people.filter { !$0.archived } }
    private var chosen: [Person] { store.selectedPeople }
    private var preview: Split? { store.draftSplit }
    private var owed: Double { preview?.parts.reduce(0) { $0 + $1.amount } ?? 0 }

    /// Only worth mentioning when the division actually left a remainder behind.
    private var hasRemainder: Bool {
        guard let preview, preview.mode == .even, let first = preview.parts.first else { return false }
        return preview.mine != first.amount
    }

    var body: some View {
        VStack(spacing: 10) {
            if isOpen {
                openBlock
            } else if chosen.isEmpty {
                closedRow
            } else {
                summaryRow
            }
            eventChips
        }
    }

    /// Collapsed, with people picked. The avatars and the user's share stay on screen, so
    /// folding the editor away hides the controls without hiding the answer.
    private var summaryRow: some View {
        Button {
            withAnimation(Tokens.easeSpring(0.3)) { isOpen = true }
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: -9) {
                    avatarBubble(SplitMath.initial(store.snapshot.userName.isEmpty ? "You" : store.snapshot.userName),
                                 Tokens.textPrimary, foreground: Tokens.bgBase)
                    ForEach(chosen.prefix(3)) { person in
                        avatarBubble(SplitMath.initial(person.name), Color(hex: person.color), foreground: Tokens.on(hex: person.color))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Split \(chosen.count + 1) ways")
                        .font(AppFont.outfit(13.5, weight: .semibold))
                        .foregroundStyle(Tokens.text)
                    Text(preview.map { "₱\(MoneyFormat.amount($0.mine)) yours · ₱\(MoneyFormat.amount(owed)) back" }
                         ?? "Type an amount")
                        .font(AppFont.outfit(11.5, weight: .medium))
                        .foregroundStyle(Tokens.muted2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.muted2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Tokens.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Tokens.line4, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func avatarBubble(_ initial: String, _ color: Color, foreground: Color) -> some View {
        Text(initial)
            .font(AppFont.outfit(11, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(Tokens.background, lineWidth: 1.5))
    }

    // MARK: - Collapsed

    private var closedRow: some View {
        Button {
            withAnimation(Tokens.easeSpring(0.3)) { isOpen = true }
        } label: {
            HStack(spacing: 10) {
                Text("🤝")
                    .font(.system(size: 13))
                    .frame(width: 26, height: 26)
                    .background(Tokens.background, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Just me")
                        .font(AppFont.outfit(13.5, weight: .semibold))
                        .foregroundStyle(Tokens.text)
                    Text("Tap to split it with someone")
                        .font(AppFont.outfit(11.5, weight: .medium))
                        .foregroundStyle(Tokens.muted2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.muted3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Tokens.dark1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded

    private var openBlock: some View {
        VStack(alignment: .leading, spacing: 11) {
            // The whole header is the collapse target, so the place the eye lands is the
            // place the finger can land.
            Button {
                withAnimation(Tokens.easeSpring(0.3)) { isOpen = false }
            } label: {
                HStack(spacing: 8) {
                    Text("🤝  Split with")
                        .font(AppFont.outfit(13, weight: .bold))
                        .foregroundStyle(Tokens.text)
                    Spacer(minLength: 8)
                    if let preview {
                        Text("₱\(MoneyFormat.amount(preview.mine)) yours")
                            .font(AppFont.outfit(12, weight: .bold))
                            .foregroundStyle(Tokens.text)
                            .monospacedDigit()
                    }
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.muted2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collapse the split")

            modePicker
                .frame(maxWidth: .infinity, alignment: .leading)

            peopleRow

            if addingPerson { addPersonRow }

            if store.splitMode != .even && store.splitMode != .theirs && !chosen.isEmpty {
                VStack(spacing: 6) {
                    ForEach(chosen) { person in
                        unevenRow(for: person)
                    }
                }
            }

            Divider().overlay(Tokens.line3)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Your share")
                        .font(AppFont.outfit(11.5, weight: .medium))
                        .foregroundStyle(Tokens.muted1)
                    Spacer(minLength: 8)
                    Text(preview.map { "₱\(MoneyFormat.amount($0.mine))" } ?? "—")
                        .font(AppFont.outfit(16, weight: .bold))
                        .foregroundStyle(Tokens.text)
                        .monospacedDigit()
                }
                if preview != nil {
                    if store.splitMode == .theirs {
                        Text("You cover nothing, they owe the full amount.")
                            .font(AppFont.outfit(11, weight: .semibold))
                            .foregroundStyle(Tokens.positive)
                    } else {
                        Text("₱\(MoneyFormat.amount(owed)) comes back to you"
                             + (hasRemainder ? " · you cover the odd centavo" : ""))
                            .font(AppFont.outfit(11, weight: .semibold))
                            .foregroundStyle(Tokens.positive)
                    }
                } else {
                    Text(chosen.isEmpty
                         ? "Pick who was in on it and the numbers appear."
                         : "Type an amount and the numbers appear.")
                        .font(AppFont.outfit(11, weight: .medium))
                        .foregroundStyle(Tokens.muted2)
                }
            }

            if !chosen.isEmpty {
                // Clearing the people is a distinct action from collapsing, so it looks like
                // a button rather than a sentence — and it leaves the event tag alone.
                Button {
                    withAnimation(Tokens.easeOut(0.24)) {
                        store.clearSplitPeople()
                        isOpen = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Actually, it was just me")
                            .font(AppFont.outfit(11.5, weight: .semibold))
                    }
                    .foregroundStyle(Tokens.muted1)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(Tokens.dark1, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Tokens.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Tokens.text, lineWidth: 1.5)
                )
        )
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach([SplitMode.even, .shares, .exact, .theirs], id: \.self) { mode in
                let on = store.splitMode == mode
                Button {
                    withAnimation(Tokens.easeOut(0.18)) { store.splitMode = mode }
                    FeedbackCenter.selectionChanged()
                } label: {
                    Text(label(for: mode))
                        .font(AppFont.outfit(11, weight: .semibold))
                        .foregroundStyle(on ? Tokens.background : Tokens.text.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(on ? Tokens.text : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Tokens.dark1, in: Capsule())
    }

    private func label(for mode: SplitMode) -> String {
        switch mode {
        case .even: "Evenly"
        case .shares: "Shares"
        case .exact: "Exact"
        case .theirs: "100% Theirs"
        }
    }

    private var peopleRow: some View {
        FlowLayout(spacing: 8) {
            // The owner is always in the split and cannot be removed — it is their wallet.
            personChip(
                initial: SplitMath.initial(store.snapshot.userName.isEmpty ? "You" : store.snapshot.userName),
                name: "You",
                color: Tokens.textPrimary,
                foreground: Tokens.bgBase,
                amount: preview?.mine,
                selected: true,
                action: nil
            )

            ForEach(roster) { person in
                personChip(
                    initial: SplitMath.initial(person.name),
                    name: person.name,
                    color: Color(hex: person.color),
                    foreground: Tokens.on(hex: person.color),
                    amount: store.splitWith.contains(person.id)
                        ? preview?.parts.first { $0.personId == person.id }?.amount
                        : nil,
                    selected: store.splitWith.contains(person.id)
                ) {
                    withAnimation(Tokens.easeSpring(0.26)) { store.toggleSplitPerson(person.id) }
                }
            }

            if !addingPerson {
                Button {
                    addingPerson = true
                    nameFocused = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Tokens.muted2)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle().strokeBorder(Tokens.muted3, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add someone")
            }
        }
    }

    private func personChip(initial: String, name: String, color: Color, foreground: Color, amount: Double?,
                            selected: Bool, action: (() -> Void)? = nil) -> some View {
        let content = VStack(spacing: 3) {
            Text(initial)
                .font(AppFont.outfit(13, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background(color, in: Circle())
                .opacity(selected ? 1 : 0.38)
                .overlay(
                    Circle()
                        .strokeBorder(Tokens.text, lineWidth: selected ? 2 : 0)
                        .padding(-3)
                )
            Text(name)
                .font(AppFont.outfit(10, weight: .medium))
                .foregroundStyle(Tokens.muted1)
                .lineLimit(1)
            // Blank rather than a dash: a "—" under a face reads as a control to tap, and
            // tapping it does nothing. The slot keeps its height so faces do not shift.
            Text(amount.map { "₱\(MoneyFormat.amount($0))" } ?? " ")
                .font(AppFont.outfit(10, weight: .semibold))
                .foregroundStyle(selected ? Tokens.text : Tokens.muted3)
                .monospacedDigit()
                .lineLimit(1)
                .frame(minHeight: 12)
        }
        .frame(width: 54)

        return Group {
            if let action {
                Button(action: action) { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var addPersonRow: some View {
        HStack(spacing: 7) {
            TextField("Their name", text: $draftName)
                .font(AppFont.outfit(13, weight: .medium))
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit(submitPerson)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Tokens.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Tokens.line4, lineWidth: 1.5)
                )

            Button("Add", action: submitPerson)
                .font(AppFont.outfit(12.5, weight: .bold))
                .foregroundStyle(draftName.trimmed.isEmpty ? Tokens.muted3 : Tokens.background)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(draftName.trimmed.isEmpty ? Tokens.dark3 : Tokens.text,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .buttonStyle(.plain)
                .disabled(draftName.trimmed.isEmpty)
        }
    }

    private func submitPerson() {
        guard !draftName.trimmed.isEmpty else { return }
        store.addPerson(draftName)
        draftName = ""
        addingPerson = false
        nameFocused = false
    }

    private func unevenRow(for person: Person) -> some View {
        HStack(spacing: 9) {
            Text(SplitMath.initial(person.name))
                .font(AppFont.outfit(10, weight: .bold))
                .foregroundStyle(Tokens.on(hex: person.color))
                .frame(width: 22, height: 22)
                .background(Color(hex: person.color), in: Circle())

            Text(person.name)
                .font(AppFont.outfit(12.5, weight: .semibold))
                .foregroundStyle(Tokens.text)
                .lineLimit(1)

            Spacer(minLength: 6)

            if store.splitMode == .shares {
                HStack(spacing: 2) {
                    Button {
                        store.setSplitShare(person.id, (store.splitShares[person.id] ?? 1) - 1)
                    } label: {
                        Text("−").font(AppFont.outfit(14, weight: .bold)).frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle((store.splitShares[person.id] ?? 1) <= 0 ? Tokens.muted4 : Tokens.text)
                    .disabled((store.splitShares[person.id] ?? 1) <= 0)
                    .accessibilityLabel("One fewer share for \(person.name)")

                    Text("\(store.splitShares[person.id] ?? 1)")
                        .font(AppFont.outfit(12.5, weight: .bold))
                        .foregroundStyle(Tokens.text)
                        .monospacedDigit()
                        .frame(minWidth: 26)

                    Button {
                        store.setSplitShare(person.id, (store.splitShares[person.id] ?? 1) + 1)
                    } label: {
                        Text("+").font(AppFont.outfit(14, weight: .bold)).frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Tokens.text)
                    .accessibilityLabel("One more share for \(person.name)")
                }
                .padding(2)
                .background(Tokens.dark1, in: Capsule())
            } else {
                HStack(spacing: 3) {
                    Text("₱")
                        .font(AppFont.outfit(12, weight: .semibold))
                        .foregroundStyle(Tokens.muted2)
                    TextField("0", text: Binding(
                        get: { store.splitExact[person.id] ?? "" },
                        set: { store.splitExact[person.id] = $0.filter { "0123456789.".contains($0) } }
                    ))
                    .font(AppFont.outfit(12.5, weight: .bold))
                    .foregroundStyle(Tokens.text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 62)
                    .accessibilityLabel("Exact amount for \(person.name)")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Tokens.dark1, in: Capsule())
            }
        }
    }

    // MARK: - Events

    /// An event is a filter on a spend, not a place in the app — so it lives as a strip of
    /// chips here rather than as a destination in the tab bar.
    @ViewBuilder
    private var eventChips: some View {
        if addingEvent {
            HStack(spacing: 7) {
                TextField("Day 1 Thailand", text: $draftEventName)
                    .font(AppFont.outfit(13, weight: .medium))
                    .focused($eventFocused)
                    .submitLabel(.done)
                    .onSubmit(submitEvent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Tokens.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Tokens.line4, lineWidth: 1.5)
                    )

                Button("Start", action: submitEvent)
                    .font(AppFont.outfit(12.5, weight: .bold))
                    .foregroundStyle(draftEventName.trimmed.isEmpty ? Tokens.muted3 : Tokens.background)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(draftEventName.trimmed.isEmpty ? Tokens.dark3 : Tokens.text,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(draftEventName.trimmed.isEmpty)
            }
        } else {
            // Closed events are still offered, but only the running ones and whatever is
            // already selected — a trip from last year is not what someone is tagging
            // tonight's dinner with.
            let offered = EventMetrics.sorted(store.snapshot.events)
                .filter { $0.endedAt == nil || $0.id == store.sheetEventID }
                .prefix(6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    if !offered.isEmpty {
                        eventChip(title: "No event", emoji: nil, on: store.sheetEventID == nil) {
                            store.sheetEventID = nil
                        }
                    }
                    ForEach(Array(offered)) { event in
                        eventChip(title: event.name, emoji: event.emoji, on: store.sheetEventID == event.id) {
                            store.sheetEventID = event.id
                        }
                    }
                    eventChip(title: offered.isEmpty ? "Start an event" : "+ Event",
                              emoji: nil, on: false, dashed: true) {
                        addingEvent = true
                        eventFocused = true
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func eventChip(title: String, emoji: String?, on: Bool,
                           dashed: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Tokens.easeOut(0.18)) { action() }
            FeedbackCenter.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                if let emoji { Text(emoji).font(.system(size: 12)) }
                Text(title)
                    .font(AppFont.outfit(12, weight: .semibold))
            }
            .foregroundStyle(on ? Tokens.background : (dashed ? Tokens.muted1 : Tokens.text))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background {
                if dashed {
                    Capsule().strokeBorder(Tokens.muted3, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                } else {
                    Capsule().fill(on ? Tokens.text : Tokens.dark1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func submitEvent() {
        guard !draftEventName.trimmed.isEmpty else { return }
        store.createEvent(draftEventName)
        draftEventName = ""
        addingEvent = false
        eventFocused = false
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
