import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct TrackScrollOffset: ViewModifier {
    let coordinateSpace: String
    
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetKey.self,
                    value: geo.frame(in: .named(coordinateSpace)).minY
                )
            }
        )
    }
}

extension View {
    func trackScrollOffset(in coordinateSpace: String = "scroll") -> some View {
        modifier(TrackScrollOffset(coordinateSpace: coordinateSpace))
    }
}
