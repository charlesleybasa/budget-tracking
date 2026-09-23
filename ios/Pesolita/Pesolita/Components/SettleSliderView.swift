import SwiftUI

/// Slide to confirm that somebody paid you back.
///
/// Settling moves real money into a real card — the one thing a shared-ledger app cannot do —
/// so it asks for a deliberate gesture rather than a tap that a pocket could trigger. The
/// character's eyes widen and the sparkles arrive as the thumb travels, which gives the extra
/// half-second a payoff instead of making it feel like friction.
struct SettleSliderView: View {
    @Bindable var store: WalletStore
    let debt: PersonDebt

    /// Frames in the atlas; progress maps onto 0–7.
    private let frames = 8
    /// How far along the track counts as committed once the thumb is released.
    private let commitAt = 0.9
    private let thumb: CGFloat = 52
    private let inset: CGFloat = 5

    @State private var progress: Double = 0
    @State private var dragging = false
    @State private var committed = false
    /// Where the money lands. Nil means "the card it came out of", which is the right default
    /// and usually right — but not always: you can pay for dinner with GCash and be handed
    /// cash back. Forcing it into the source card would leave both cards disagreeing with
    /// what is actually in them, which is the one thing a manual wallet cannot afford.
    @State private var intoID: String?
    @State private var picking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var frame: Int { Int((progress * Double(frames - 1)).rounded()) }

    private var landingCard: Card? {
        if let intoID, let chosen = store.snapshot.cards.first(where: { $0.id == intoID }) { return chosen }
        return store.pendingSettleCard
    }

    var body: some View {
        VStack(spacing: 0) {
                Capsule()
                    .fill(Tokens.line1)
                    .frame(width: 34, height: 4)
                    .padding(.top, 10)

                character
                    .padding(.top, 6)

                Text("\(debt.name.uppercased()) PAID YOU BACK")
                    .font(AppFont.outfit(12, weight: .medium))
                    .kerning(1.1)
                    .foregroundStyle(Tokens.text.opacity(0.6))
                    .padding(.top, 2)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("+₱")
                        .font(AppFont.outfit(22, weight: .bold))
                        .foregroundStyle(Tokens.positive)
                    Text(MoneyFormat.amount(debt.amount))
                        .font(AppFont.outfit(40, weight: .bold))
                        .foregroundStyle(Tokens.text)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.top, 4)

                Text("Across \(debt.count == 1 ? "1 spend" : "\(debt.count) spends").")
                    .font(AppFont.outfit(13))
                    .foregroundStyle(Tokens.text.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .padding(.top, 4)

                if let card = landingCard { landingRow(card) }

                track
                    .padding(.top, 16)

                // Dragging is not available to everyone, so the same commitment is one press
                // away — present from the start rather than appearing only on failure.
                Button("Or tap here to confirm") { commit() }
                    .font(AppFont.outfit(12, weight: .semibold))
                    .foregroundStyle(Tokens.text.opacity(0.8))
                    .frame(minHeight: 40)
                    .padding(.top, 2)
                    .buttonStyle(.plain)

                Button("Not yet") { store.cancelSettle() }
                    .font(AppFont.outfit(13, weight: .semibold))
                    .foregroundStyle(Tokens.text.opacity(0.4))
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
        .sheet(isPresented: $picking) {
            MoneyCardPickerSheet(
                title: "Land it in",
                cards: store.snapshot.cards,
                selectedID: landingCard?.id ?? "",
                privateMode: store.snapshot.privacy
            ) { id in
                intoID = id
                picking = false
            }
        }
    }

    private func landingRow(_ card: Card) -> some View {
        Button {
            picking = true
        } label: {
            HStack(spacing: 11) {
                CardArtView(art: card.art, cornerRadius: 7, stretchesToFill: true)
                    .frame(width: 48, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Tokens.line4, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text("LANDS IN")
                        .font(AppFont.outfit(10, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(Tokens.text.opacity(0.6))
                    Text(card.nick)
                        .font(AppFont.outfit(14, weight: .bold))
                        .foregroundStyle(Tokens.text)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if store.snapshot.cards.count > 1 {
                    HStack(spacing: 4) {
                        Text("Change")
                            .font(AppFont.outfit(13, weight: .bold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Tokens.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Tokens.background.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(Tokens.hairlineStrong, lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Tokens.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Tokens.hairlineStrong, lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        // With one card there is nothing to change to, but where the money lands is still
        // worth reading — so the row stops taking taps instead of greying itself out.
        .allowsHitTesting(!committed && store.snapshot.cards.count > 1)
        .padding(.top, 14)
        .accessibilityLabel("Lands in \(card.nick). Change card")
    }

    // MARK: - Character

    private var character: some View {
        ZStack {
            // The glow warms up with the drag, so the screen itself reacts rather than only
            // the sprite changing.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Tokens.accent.opacity(0.55), Tokens.accent.opacity(0)],
                        center: .center, startRadius: 4, endRadius: 95
                    )
                )
                .frame(width: 190, height: 190)
                .opacity(progress * 0.9)

            SpriteFrameView(spec: .settleSlider, frame: frame)
                .frame(width: 168, height: 168)
                
            FlyingCoinsView(progress: progress)
        }
        .frame(height: 176)
        .accessibilityHidden(true)
    }

    // MARK: - Track

    private var track: some View {
        GeometryReader { geo in
            let travel = max(0, geo.size.width - thumb - inset * 2)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Tokens.hairlineStrong, lineWidth: 1))

                Capsule()
                    .fill(LinearGradient(colors: [Tokens.greenDeep, Tokens.green],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: inset * 2 + thumb + travel * progress)

                Text("Slide to confirm")
                    .font(AppFont.outfit(14, weight: .bold))
                    .foregroundStyle(Tokens.text.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 46)
                    .opacity(max(0, 1 - progress * 1.6))

                // Arrives late on purpose: ramping it in from halfway put the word directly
                // under the thumb, and a confirmation with a thumb through it is not one.
                Text("Got it back")
                    .font(AppFont.outfit(14, weight: .bold))
                    .foregroundStyle(Tokens.text)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 46)
                    .opacity(max(0, progress * 5 - 4))

                Circle()
                    .fill(.white)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                    .overlay(
                        Image(systemName: committed ? "checkmark" : "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                    )
                    .offset(x: inset + travel * progress)
                    .animation(dragging || reduceMotion ? nil : Tokens.easeSpring(0.32), value: progress)
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !committed else { return }
                        dragging = true
                        progress = clamp((value.location.x - inset - thumb / 2) / max(1, travel))
                    }
                    .onEnded { _ in
                        guard !committed else { return }
                        dragging = false
                        // Past the line it commits; short of it the thumb springs back rather
                        // than sitting in a half-done state the user has to interpret.
                        if progress >= commitAt { commit() } else { progress = 0 }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Slide to confirm ₱\(MoneyFormat.amount(debt.amount)) from \(debt.name)")
            .accessibilityValue("\(Int(progress * 100)) percent")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { commit() }
        }
        .frame(height: 62)
    }

    private func clamp(_ value: Double) -> Double { min(1, max(0, value)) }

    private func commit() {
        guard !committed else { return }
        committed = true
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.15)) { progress = 1 }
        FeedbackCenter.snap()
        // Let the last frame and the filled track land before the success screen takes over.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let pending = store.pendingSettle else { return }
            store.settle(personID: pending.personID,
                         transactionID: pending.txID.isEmpty ? nil : pending.txID,
                         into: landingCard?.id)
        }
    }
}

/// One still frame of a sprite atlas, addressed by index. The animated `SpriteAnimationView`
/// drives itself from a clock; this one is driven by a gesture.
struct SpriteFrameView: View {
    let spec: SpriteSpec
    let frame: Int

    var body: some View {
        let frames = SpriteFrameCache.frames(for: spec)
        Group {
            if frames.indices.contains(frame) {
                Image(uiImage: frames[frame])
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Interactive Coin Animation

struct MascotCoin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .orange.opacity(0.8), radius: 2, x: 0, y: 1)
            Circle()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .orange.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            Text("₱")
                .font(AppFont.outfit(14, weight: .bold))
                .foregroundStyle(Tokens.text)
                .shadow(color: .orange.opacity(0.8), radius: 1, x: 0, y: 1)
        }
        .frame(width: 26, height: 26)
    }
}

struct CoinSpec {
    let startX: CGFloat
    let startY: CGFloat
    let arcHeight: CGFloat
    let spinSpeed: Double
    let delay: Double
}

struct FlyingCoinsView: View {
    let progress: Double
    
    // Spread the coins around the mascot, they all arc upwards and land in the pouch
    // The pouch on the mascot is roughly at (0, 36) relative to center.
    let coins: [CoinSpec] = [
        CoinSpec(startX: -130, startY: -20, arcHeight: 80, spinSpeed: 2.5, delay: 0.0),
        CoinSpec(startX: 120, startY: 10, arcHeight: 90, spinSpeed: -3.0, delay: 0.1),
        CoinSpec(startX: -100, startY: 70, arcHeight: 60, spinSpeed: 3.5, delay: 0.2),
        CoinSpec(startX: 140, startY: 50, arcHeight: 70, spinSpeed: -2.0, delay: 0.25),
        CoinSpec(startX: -110, startY: 20, arcHeight: 100, spinSpeed: 4.0, delay: 0.15),
        CoinSpec(startX: 100, startY: -40, arcHeight: 85, spinSpeed: -3.5, delay: 0.05)
    ]
    
    var body: some View {
        ZStack {
            ForEach(0..<coins.count, id: \.self) { i in
                let spec = coins[i]
                
                // Map the global slider progress to this specific coin's timeline
                let coinLength = 1.0 - spec.delay
                let p = max(0, min(1, (progress - spec.delay) / coinLength))
                
                // Opacity fades out right as it enters the pouch
                let opacity = p > 0 ? (p < 0.95 ? 1.0 : 1.0 - (p - 0.95) * 20) : 0.0
                
                // Move from start position to pouch (0, 36)
                let currentX = spec.startX + (0 - spec.startX) * p
                let baseCurrentY = spec.startY + (36 - spec.startY) * p
                
                // Add a parabolic arc to the Y movement
                let currentY = baseCurrentY - spec.arcHeight * sin(p * .pi)
                
                MascotCoin()
                    .rotation3DEffect(.degrees(p * 360 * spec.spinSpeed), axis: (x: 1, y: 1, z: 0))
                    // Shrink it as it goes "into" the pouch
                    .scaleEffect(p > 0.8 ? 1.0 - (p - 0.8) * 3 : 1.0)
                    .offset(x: currentX, y: currentY)
                    .opacity(opacity)
            }
        }
    }
}
