import SwiftUI
@available(iOS 18.0, *)
struct TestScroll: View {
    var body: some View {
        ScrollView {
            Text("Hi")
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { old, new in
            print(new)
        }
    }
}
