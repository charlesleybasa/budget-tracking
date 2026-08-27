import SwiftUI
import UIKit

struct SpriteSpec: Hashable, Sendable {
    var resource: String
    var columns: Int
    var rows: Int
    var frames: Int
    var fps: Double
    var stillFrame: Int
    var loops = true
    var replayDelay: Double = 0

    static let celebrate = SpriteSpec(resource: "celebrate", columns: 8, rows: 4, frames: 32, fps: 24, stillFrame: 19)
    static let peekaboo = SpriteSpec(resource: "peekaboo", columns: 9, rows: 6, frames: 54, fps: 24, stillFrame: 30, loops: false, replayDelay: 3)
    static let flyingIdle = SpriteSpec(resource: "flying-idle", columns: 10, rows: 6, frames: 60, fps: 24, stillFrame: 7)
    static let noNoNo = SpriteSpec(resource: "nonono", columns: 10, rows: 6, frames: 60, fps: 24, stillFrame: 36, loops: false, replayDelay: 2.4)
    // This atlas is 10 × 3 (30 frames). Treating it as 10 × 6 crops every
    // character frame in half, which is why the Search mascot appeared headless.
    static let idleSteady = SpriteSpec(resource: "bee-idle-steady-30fps-v2-spritesheet", columns: 10, rows: 3, frames: 30, fps: 30, stillFrame: 15)
}

@MainActor
private enum SpriteFrameCache {
    static var cache: [SpriteSpec: [UIImage]] = [:]

    static func frames(for spec: SpriteSpec) -> [UIImage] {
        if let cached = cache[spec] { return cached }
        let url = Bundle.main.resourceURL?
            .appendingPathComponent("Sprites", isDirectory: true)
            .appendingPathComponent("\(spec.resource).png")
        let resolved = url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            ?? Bundle.main.url(forResource: spec.resource, withExtension: "png")
        guard let resolved, let image = UIImage(contentsOfFile: resolved.path), let source = image.cgImage else { return [] }
        let cellWidth = source.width / spec.columns
        let cellHeight = source.height / spec.rows
        let frames = (0..<spec.frames).compactMap { index -> UIImage? in
            let rect = CGRect(
                x: (index % spec.columns) * cellWidth,
                y: (index / spec.columns) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
            guard let crop = source.cropping(to: rect) else { return nil }
            return UIImage(cgImage: crop, scale: image.scale, orientation: .up)
        }
        cache[spec] = frames
        return frames
    }
}

struct SpriteAnimationView: View {
    var spec: SpriteSpec
    var size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let startedAt = Date.now.timeIntervalSinceReferenceDate

    var body: some View {
        let frames = SpriteFrameCache.frames(for: spec)
        Group {
            if frames.isEmpty {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.36))
                    .foregroundStyle(Tokens.accent)
            } else if reduceMotion {
                frame(frames, index: spec.stillFrame)
            } else {
                TimelineView(.animation(minimumInterval: 1 / spec.fps)) { timeline in
                    frame(frames, index: frameIndex(at: timeline.date, count: frames.count))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func frameIndex(at date: Date, count: Int) -> Int {
        let elapsed = max(0, date.timeIntervalSinceReferenceDate - startedAt)
        let animationDuration = Double(spec.frames) / spec.fps
        if spec.loops { return min(count - 1, Int(elapsed * spec.fps) % spec.frames) }
        let cycle = animationDuration + spec.replayDelay
        let local = elapsed.truncatingRemainder(dividingBy: max(animationDuration, cycle))
        return local >= animationDuration ? min(count - 1, spec.frames - 1) : min(count - 1, Int(local * spec.fps))
    }

    private func frame(_ frames: [UIImage], index: Int) -> some View {
        Image(uiImage: frames[min(max(0, index), frames.count - 1)])
            .resizable()
            .scaledToFit()
    }
}
