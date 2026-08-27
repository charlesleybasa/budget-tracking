import PhotosUI
import SwiftUI

struct TransactionEditorView: View {
    @Bindable var store: WalletStore
    @State private var photoItem: PhotosPickerItem?
    @State private var deleteOpen = false
    @State private var amountField = ""

    private var draft: TransactionEditorDraft? { store.transactionEditor }
    private var transaction: Transaction? {
        guard let id = draft?.transactionID else { return nil }
        return store.snapshot.tx.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Tokens.sand4).frame(width: 40, height: 5).padding(.top, 10)
            HStack {
                Text("Edit activity")
                    .font(AppFont.outfit(23, weight: .black, relativeTo: .title2))
                Spacer()
                Button { store.transactionEditor = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.bordered).buttonBorderShape(.circle).tint(Tokens.sand2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if let draft, let transaction {
                ScrollView {
                    VStack(spacing: 17) {
                        VStack(spacing: 5) {
                            Text(transaction.amount > 0 ? "MONEY IN" : "MONEY OUT")
                                .font(AppFont.outfit(10, weight: .bold, relativeTo: .caption2))
                                .tracking(1.2)
                                .foregroundStyle(transaction.amount > 0 ? Tokens.green : Tokens.red)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("₱")
                                TextField("0.00", text: $amountField)
                                    .keyboardType(.decimalPad)
                                    .onAppear { syncAmountField() }
                                    .onChange(of: amountField) { _, typed in amountFieldChanged(typed) }
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(AppFont.outfit(39, weight: .black, relativeTo: .largeTitle))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("What was it?")
                            TextField("Merchant or note", text: noteBinding)
                                .font(AppFont.outfit(14, weight: .medium, relativeTo: .body))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 48)
                                .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("Category")
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(CategoryName.allCases) { category in
                                        Button {
                                            store.transactionEditor?.category = category
                                            FeedbackCenter.selectionChanged()
                                        } label: {
                                            Label(category.rawValue, systemImage: store.transactionEditor?.category == category ? "checkmark.circle.fill" : "circle.fill")
                                                .font(AppFont.outfit(11.5, weight: .bold, relativeTo: .caption))
                                                .foregroundStyle(store.transactionEditor?.category == category ? .white : Tokens.ink)
                                                .padding(.horizontal, 12)
                                                .frame(minHeight: 38)
                                                .background(store.transactionEditor?.category == category ? Tokens.ink : Tokens.sand1, in: Capsule())
                                        }
                                        .buttonStyle(PesolitaPressStyle())
                                    }
                                }
                            }
                            .scrollIndicators(.hidden)
                        }

                        if let receipt = draft.receipt {
                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Receipt")
                                Button { store.receiptViewerTransactionID = transaction.id } label: {
                                    ResourceImage(reference: receipt)
                                        .frame(height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(alignment: .bottomTrailing) {
                                            Label("View", systemImage: "arrow.up.left.and.arrow.down.right")
                                                .font(AppFont.outfit(10.5, weight: .bold, relativeTo: .caption2))
                                                .padding(9)
                                                .background(.ultraThinMaterial, in: Capsule())
                                                .padding(10)
                                        }
                                }
                                .buttonStyle(PesolitaPressStyle())
                                HStack {
                                    PhotosPicker(selection: $photoItem, matching: .images) {
                                        Label("Replace", systemImage: "camera")
                                    }
                                    Spacer()
                                    Button(role: .destructive) { store.transactionEditor?.receipt = nil } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                                .font(AppFont.outfit(12, weight: .bold, relativeTo: .caption))
                            }
                        } else {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("Attach a receipt", systemImage: "camera.fill")
                                    .font(AppFont.outfit(12.5, weight: .bold, relativeTo: .caption))
                                    .foregroundStyle(Tokens.ink)
                                    .frame(maxWidth: .infinity, minHeight: 47)
                                    .background(Tokens.sand1, in: Capsule())
                            }
                        }

                        Button { store.saveTransactionEditor() } label: {
                            Text("Save changes")
                                .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(Tokens.ink, in: Capsule())
                        }
                        .buttonStyle(PesolitaPressStyle())

                        Button(role: .destructive) {
                            deleteOpen = true
                            FeedbackCenter.warning()
                        } label: {
                            Label("Delete this entry", systemImage: "trash")
                                .font(AppFont.outfit(13, weight: .bold, relativeTo: .subheadline))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 34)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
        }
        .background(.white)
        .preferredColorScheme(.light)
        .presentationDragIndicator(.hidden)
        .presentationDetents([.large])
        .presentationCornerRadius(30)
        .alert("Delete this entry?", isPresented: $deleteOpen) {
            Button("Keep it", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let id = transaction?.id { store.deleteTransaction(id) }
            }
        } message: {
            Text("Its amount will be put back into the card balance so the numbers stay correct.")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await store.attachTransactionEditorReceipt(data)
                }
            }
        }
    }

    private func syncAmountField() {
        amountField = MoneyFormat.grouped(draft: store.transactionEditor?.amount ?? "")
    }

    private func amountFieldChanged(_ typed: String) {
        let raw = MoneyFormat.ungrouped(typed)
        let grouped = MoneyFormat.grouped(draft: raw)
        if grouped != typed { amountField = grouped }
        store.transactionEditor?.amount = raw
    }

    private var noteBinding: Binding<String> {
        Binding(get: { store.transactionEditor?.note ?? "" }, set: { store.transactionEditor?.note = $0 })
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppFont.outfit(10, weight: .semibold, relativeTo: .caption2))
            .tracking(1.1)
            .foregroundStyle(Tokens.muted2)
    }
}
