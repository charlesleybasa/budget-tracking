import SwiftUI

struct MoneyKeypad: View {
    var onKey: (String) -> Void
    var dark = false
    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "⌫"]]

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 8) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            onKey(key)
                        } label: {
                            Group {
                                if key == "⌫" { Image(systemName: "delete.left") }
                                else { Text(key) }
                            }
                            .font(AppFont.outfit(22, weight: .semibold, relativeTo: .title2))
                            .foregroundStyle(dark ? Color.white : Tokens.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PesolitaPressStyle())
                        .background(dark ? Tokens.dark2 : Tokens.sand1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(key == "⌫" ? "Delete" : key)
                    }
                }
            }
        }
    }
}
