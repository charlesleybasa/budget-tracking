import SwiftUI

struct MoneyKeypad: View {
    var onKey: (String) -> Void
    var dark = false
    @Environment(\.layout) private var layout
    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "⌫"]]

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: layout.isShort ? 6 : 8) {
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
                            .foregroundStyle(Tokens.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: layout.keypadKeyHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PesolitaPressStyle())
                        .background(Tokens.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(key == "⌫" ? "Delete" : key)
                    }
                }
            }
        }
        // Keys stay thumb-sized on a wide window instead of stretching to 200 pt each.
        .frame(maxWidth: LayoutMetrics.controlMaxWidth)
        .frame(maxWidth: .infinity)
    }
}
