import AVFoundation
import UIKit

/// Native counterpart of Android's `lib/feedback.ts`. Cues use the same oscillator, glide,
/// duration and gain values, so feedback is instant and needs no bundled audio clips.
@MainActor
enum FeedbackCenter {
    enum Sound: Hashable {
        case tap, key, toggleOn, toggleOff, open, close, spend, coin, success, error, delete
    }

    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()
    private static let synth = FeedbackSynthesizer()
    private static var hapticsOn = true
    private static var soundsOn = true

    static func configure(haptics: Bool, sounds: Bool) {
        hapticsOn = haptics
        soundsOn = sounds
        if sounds { synth.prepare() }
    }

    static func prepare() {
        selection.prepare(); light.prepare(); medium.prepare(); heavy.prepare(); notification.prepare()
        synth.prepare()
    }

    static func selectionChanged() { selectionHaptic(); play(.tap) }
    static func tap() { impact(.light, intensity: 0.72); play(.tap) }
    static func key() { selectionHaptic(); play(.key) }
    static func snap() { impact(.medium, intensity: 0.66); play(.tap) }
    static func opened() { impact(.medium, intensity: 0.78); play(.open) }
    static func closed() { impact(.light, intensity: 0.72); play(.close) }
    static func toggle(on: Bool) { impact(.medium, intensity: 0.74); play(on ? .toggleOn : .toggleOff) }
    static func success() { notify(.success); play(.success) }
    static func moneyOut() { notify(.success); play(.spend) }
    static func moneyIn() { notify(.success); play(.coin) }
    static func moved() { notify(.success); play(.success) }
    static func warning() { notify(.warning); play(.error) }
    static func destructive() { notify(.error); play(.delete) }
    static func previewSoundEnabled() { synth.play(.toggleOn) }

    private static func selectionHaptic() {
        guard hapticsOn else { return }
        selection.selectionChanged(); selection.prepare()
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        guard hapticsOn else { return }
        let generator = style == .light ? light : style == .heavy ? heavy : medium
        generator.impactOccurred(intensity: intensity); generator.prepare()
    }

    private static func notify(_ kind: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsOn else { return }
        notification.notificationOccurred(kind); notification.prepare()
    }

    private static func play(_ sound: Sound) {
        guard soundsOn else { return }
        synth.play(sound)
    }
}

@MainActor
private final class FeedbackSynthesizer {
    private enum Wave { case sine, triangle, square }
    private struct Tone {
        var frequency: Double
        var target: Double? = nil
        var duration: Double
        var delay: Double = 0
        var gain: Double = 1
        var wave: Wave = .sine
    }
    private struct Click {
        var duration: Double
        var delay: Double = 0
        var frequency: Double = 1_800
        var q: Double = 6
        var gain: Double = 1
    }
    private struct Cue { var tones: [Tone] = []; var clicks: [Click] = [] }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [FeedbackCenter.Sound: AVAudioPCMBuffer] = [:]
    private var ready = false
    private let sampleRate = 48_000.0
    private let masterGain = 0.16

    func prepare() {
        guard !ready else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            try engine.start()
            ready = true
        } catch { ready = false }
    }

    func play(_ sound: FeedbackCenter.Sound) {
        prepare()
        guard ready else { return }
        let buffer = buffers[sound] ?? render(sound)
        buffers[sound] = buffer
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func render(_ sound: FeedbackCenter.Sound) -> AVAudioPCMBuffer {
        let cue = cue(for: sound)
        let end = max(cue.tones.map { $0.delay + $0.duration }.max() ?? 0,
                      cue.clicks.map { $0.delay + $0.duration }.max() ?? 0) + 0.025
        let count = max(1, Int(ceil(end * sampleRate)))
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = AVAudioFrameCount(count)
        guard let output = buffer.floatChannelData?[0] else { return buffer }
        for tone in cue.tones { mix(tone, into: output, count: count) }
        for (index, click) in cue.clicks.enumerated() {
            mix(click, seed: UInt64(index + 1) &+ UInt64(sound.hashValue.magnitude), into: output, count: count)
        }
        for index in 0..<count {
            output[index] = Float(max(-0.96, min(0.96, Double(output[index]) * masterGain)))
        }
        return buffer
    }

    private func mix(_ tone: Tone, into output: UnsafeMutablePointer<Float>, count: Int) {
        let start = max(0, Int(tone.delay * sampleRate))
        let frames = max(1, Int(tone.duration * sampleRate))
        var phase = 0.0
        for frame in 0..<frames where start + frame < count {
            let time = Double(frame) / sampleRate
            let progress = min(1, time / max(tone.duration, 0.0001))
            let frequency = tone.target.map { tone.frequency * pow($0 / tone.frequency, progress) } ?? tone.frequency
            phase += 2 * Double.pi * frequency / sampleRate
            let wave: Double = switch tone.wave {
            case .sine: sin(phase)
            case .triangle: (2 / Double.pi) * asin(sin(phase))
            case .square: sin(phase) >= 0 ? 1 : -1
            }
            let attack = min(0.005, tone.duration * 0.45)
            let envelope: Double
            if time <= attack {
                envelope = 0.0001 * pow(max(tone.gain, 0.0001) / 0.0001, time / max(attack, 0.0001))
            } else {
                envelope = tone.gain * pow(0.0001 / max(tone.gain, 0.0001), (time - attack) / max(tone.duration - attack, 0.0001))
            }
            output[start + frame] += Float(wave * envelope)
        }
    }

    private func mix(_ click: Click, seed: UInt64, into output: UnsafeMutablePointer<Float>, count: Int) {
        let start = max(0, Int(click.delay * sampleRate))
        let frames = max(1, Int(click.duration * sampleRate))
        let omega = 2 * Double.pi * click.frequency / sampleRate
        let alpha = sin(omega) / (2 * click.q)
        let a0 = 1 + alpha
        let b0 = (sin(omega) / 2) / a0
        let b2 = -b0
        let a1 = (-2 * cos(omega)) / a0
        let a2 = (1 - alpha) / a0
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        var random = seed == 0 ? 1 : seed
        for frame in 0..<frames where start + frame < count {
            random = 6_364_136_223_846_793_005 &* random &+ 1_442_695_040_888_963_407
            let unit = Double((random >> 11) & 0x1f_ffff) / Double(0x1f_ffff)
            let x0 = (unit * 2 - 1) * pow(1 - Double(frame) / Double(frames), 3)
            let y0 = b0 * x0 + b2 * x2 - a1 * y1 - a2 * y2
            output[start + frame] += Float(y0 * click.gain)
            x2 = x1; x1 = x0; y2 = y1; y1 = y0
        }
    }

    private func cue(for sound: FeedbackCenter.Sound) -> Cue {
        switch sound {
        case .tap: Cue(clicks: [Click(duration: 0.03, frequency: 2_000, q: 8, gain: 0.5)])
        case .key: Cue(tones: [Tone(frequency: 880, duration: 0.045, gain: 0.16, wave: .triangle)], clicks: [Click(duration: 0.025, frequency: 1_400, q: 5, gain: 0.45)])
        case .toggleOn: Cue(tones: [Tone(frequency: 620, target: 940, duration: 0.09, gain: 0.3, wave: .triangle)])
        case .toggleOff: Cue(tones: [Tone(frequency: 940, target: 620, duration: 0.09, gain: 0.3, wave: .triangle)])
        case .open: Cue(tones: [Tone(frequency: 420, target: 760, duration: 0.14, gain: 0.22)], clicks: [Click(duration: 0.06, frequency: 900, q: 1.2, gain: 0.28)])
        case .close: Cue(tones: [Tone(frequency: 700, target: 380, duration: 0.12, gain: 0.2)], clicks: [Click(duration: 0.05, frequency: 700, q: 1.2, gain: 0.22)])
        case .spend: Cue(tones: [Tone(frequency: 784, duration: 0.1, gain: 0.34, wave: .triangle), Tone(frequency: 523.25, duration: 0.22, delay: 0.075, gain: 0.3, wave: .triangle)])
        case .coin: Cue(tones: [Tone(frequency: 659.25, duration: 0.09, gain: 0.32, wave: .triangle), Tone(frequency: 987.77, duration: 0.24, delay: 0.07, gain: 0.28, wave: .triangle), Tone(frequency: 1_975.53, duration: 0.16, delay: 0.07, gain: 0.09)])
        case .success: Cue(tones: [Tone(frequency: 523.25, duration: 0.16, gain: 0.3, wave: .triangle), Tone(frequency: 659.25, duration: 0.18, delay: 0.055, gain: 0.28, wave: .triangle), Tone(frequency: 783.99, duration: 0.34, delay: 0.11, gain: 0.26, wave: .triangle)])
        case .error: Cue(tones: [Tone(frequency: 196, duration: 0.1, gain: 0.22, wave: .square), Tone(frequency: 155.56, duration: 0.16, delay: 0.1, gain: 0.22, wave: .square)])
        case .delete: Cue(tones: [Tone(frequency: 320, target: 150, duration: 0.16, gain: 0.24)], clicks: [Click(duration: 0.05, frequency: 600, q: 1.5, gain: 0.3)])
        }
    }
}
