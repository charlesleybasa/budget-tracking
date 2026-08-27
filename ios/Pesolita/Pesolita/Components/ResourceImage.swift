import SwiftUI
import UIKit

@MainActor
enum ResourceImageLoader {
    private static var cache: [String: UIImage] = [:]

    static func image(reference: String) -> UIImage? {
        if let cached = cache[reference] { return cached }
        let image: UIImage?
        if reference.hasPrefix("template:") {
            let path = String(reference.dropFirst("template:".count))
            let url = Bundle.main.resourceURL?
                .appendingPathComponent("CardTemplates", isDirectory: true)
                .appendingPathComponent(path)
            let flatURL = Bundle.main.url(
                forResource: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
                withExtension: "webp"
            )
            image = (url.flatMap { UIImage(contentsOfFile: $0.path) })
                ?? flatURL.flatMap { UIImage(contentsOfFile: $0.path) }
        } else if reference.hasPrefix("file:") {
            let name = String(reference.dropFirst("file:".count))
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Pesolita/Media", isDirectory: true)
            image = UIImage(contentsOfFile: root.appendingPathComponent(name).path)
        } else if reference.hasPrefix("data:"), let comma = reference.firstIndex(of: ",") {
            image = Data(base64Encoded: String(reference[reference.index(after: comma)...])).flatMap(UIImage.init(data:))
        } else {
            image = UIImage(named: reference)
        }
        if let image { cache[reference] = image }
        return image
    }
}

struct ResourceImage: View {
    var reference: String
    var contentMode: ContentMode = .fill

    var body: some View {
        if let image = ResourceImageLoader.image(reference: reference) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Color(hex: "#16161a")
        }
    }
}
