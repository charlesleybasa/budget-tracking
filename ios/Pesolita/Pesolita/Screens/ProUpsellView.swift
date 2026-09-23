import SwiftUI

/// The Pesolita Pro sheet. One sheet for three moments — buying Pro, turning backup on, and
/// checking on a backup that is running — and it sizes itself to whichever one is showing, so
/// it never opens as a tall, mostly-empty page.
struct ProUpsellView: View {
    @Bindable var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var syncManager: SyncManager

    @State private var isFloating = false
    @State private var showSparkles = false
    @State private var confirmingSignOut = false
    @State private var contentHeight: CGFloat = 560

    private enum Stage: Equatable { case buy, turnOnBackup, backedUp }

    private var stage: Stage {
        if syncManager.isAuthenticated { return .backedUp }
        if storeManager.hasPro || store.isPro { return .turnOnBackup }
        return .buy
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                    .padding(.top, 20)

                Group {
                    switch stage {
                    case .buy: buyStage
                    case .turnOnBackup: turnOnBackupStage
                    case .backedUp: backedUpStage
                    }
                }
                .padding(.top, 20)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .background(backdrop)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.86), value: stage)
        // Fits the sheet to what is showing; very large text falls back to a scrolling page.
        .presentationDetents([.height(contentHeight + 24)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Tokens.bgBase)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { isFloating = true }
        }
        .onChange(of: storeManager.hasPro) { was, now in
            if !was && now { celebrate() }
        }
        .task {
            await storeManager.loadProducts()
            await storeManager.updatePurchasedStatus()
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                // A soft gold halo, stronger at night where it has room to glow.
                Circle()
                    .fill(RadialGradient(colors: [Tokens.accent.opacity(scheme == .dark ? 0.42 : 0.36), Tokens.accent.opacity(0)],
                                         center: .center, startRadius: 4, endRadius: 80))
                    .frame(width: 170, height: 170)
                    .scaleEffect(isFloating ? 1.06 : 0.96)
                Image("ProMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .shadow(color: Tokens.accent.opacity(0.35), radius: 18, y: 10)
                    .offset(y: isFloating ? -5 : 5)
                if showSparkles { SparklesView() }
            }
            .frame(height: 118)
            .accessibilityHidden(true)

            Label(stage == .buy ? "PESOLITA PRO" : "PRO IS ON", systemImage: stage == .buy ? "crown.fill" : "checkmark.seal.fill")
                .font(AppFont.outfit(11, weight: .bold, relativeTo: .caption2))
                .tracking(1.4)
                .foregroundStyle(Tokens.accentText)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Tokens.accentTint, in: Capsule())
                .overlay(Capsule().strokeBorder(Tokens.accent.opacity(0.35), lineWidth: 1))

            Text(title)
                .font(AppFont.outfit(30, weight: .black, relativeTo: .largeTitle))
                .foregroundStyle(Tokens.textPrimary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            Text(subtitle)
                .font(AppFont.outfit(15, relativeTo: .body))
                .foregroundStyle(Tokens.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
    }

    private var title: String {
        switch stage {
        case .buy: "Keep every peso safe"
        case .turnOnBackup: "Turn on your backup"
        case .backedUp: backupHeadline
        }
    }

    private var subtitle: String {
        switch stage {
        case .buy: "Your wallet, backed up and ready on any iPhone. One payment, yours for good."
        case .turnOnBackup: "Pesolita Pro is unlocked. Sign in with Google and your wallet backs itself up from now on."
        case .backedUp: "Every change on this iPhone is saved to your Google account."
        }
    }

    private var backupHeadline: String {
        switch syncManager.phase {
        case .needsDecision: "Your backup needs a look"
        case .paused(.unreachable): "Backup can't connect"
        case .paused(.notPro): "Backup is paused"
        case .reconciling: "Checking your backup"
        default: "You're backed up"
        }
    }

    // MARK: Stage — buy

    private var buyStage: some View {
        VStack(spacing: 18) {
            VStack(spacing: 0) {
                benefitRow("icloud.and.arrow.up.fill", tint: Tokens.link, tile: Tokens.blueTint,
                           title: "Automatic backup", detail: "Every change saved as you go.")
                divider
                benefitRow("iphone.gen3", tint: Tokens.positive, tile: Tokens.greenTint,
                           title: "Back on any iPhone", detail: "New phone? Sign in and it's all there.")
                divider
                benefitRow("photo.stack.fill", tint: Tokens.violetText, tile: Tokens.violetTint,
                           title: "Photos and QR codes too", detail: "Card photos, QR codes and receipts.")
                divider
                benefitRow("hand.raised.fill", tint: Tokens.accentText, tile: Tokens.accentTint,
                           title: "No ads, no tracking", detail: "Your backup is only used to restore it.")
            }
            .padding(.vertical, 6)
            .background(Tokens.fill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Tokens.hairline, lineWidth: 1))

            HStack(spacing: 14) {
                promise("One-time")
                promise("No subscription")
                promise("Yours forever")
            }
            .frame(maxWidth: .infinity)

            ProPurchaseButton()
                .shadow(color: Tokens.accent.opacity(scheme == .dark ? 0.28 : 0.4), radius: 18, y: 8)

            HStack(spacing: 0) {
                RestorePurchasesButton()
                Text("·").foregroundStyle(Tokens.textTertiary).padding(.horizontal, 10)
                laterButton("Maybe later")
            }
            debugControls
        }
    }

    private func promise(_ text: String) -> some View {
        Label(text, systemImage: "checkmark")
            .font(AppFont.outfit(12, weight: .semibold, relativeTo: .caption))
            .foregroundStyle(Tokens.textSecondary)
            .labelStyle(PromiseLabelStyle())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    // MARK: Stage — Pro on, backup off

    private var turnOnBackupStage: some View {
        VStack(spacing: 18) {
            VStack(spacing: 0) {
                stepRow(number: nil, title: "Pesolita Pro unlocked", detail: "Thank you for supporting Pesolita.")
                divider
                stepRow(number: 2, title: "Sign in with Google", detail: "Use the account your wallet should live in. Already have a backup? We'll find it — nothing is overwritten.")
            }
            .padding(.vertical, 6)
            .background(Tokens.fill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Tokens.hairline, lineWidth: 1))

            GoogleButton {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    store.openRestoreFlow(startSignIn: true)
                }
            }
            laterButton("Not now")
            debugControls
        }
    }

    private func stepRow(number: Int?, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(number == nil ? Tokens.greenDeep : Tokens.accent)
                if let number {
                    Text("\(number)")
                        .font(AppFont.outfit(14, weight: .bold))
                        .foregroundStyle(Tokens.onAccent)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Tokens.onBrand)
                }
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.outfit(15.5, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(number == nil ? Tokens.textSecondary : Tokens.textPrimary)
                Text(detail)
                    .font(AppFont.outfit(13, relativeTo: .subheadline))
                    .foregroundStyle(Tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: Stage — backed up

    private var backedUpStage: some View {
        VStack(spacing: 18) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(status.tile)
                        if syncManager.isSyncing || syncManager.phase == .reconciling {
                            ProgressView().tint(status.tint)
                        } else {
                            Image(systemName: status.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(status.tint)
                                .symbolEffect(.bounce, value: syncManager.lastSyncTime)
                        }
                    }
                    .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(status.title)
                            .font(AppFont.outfit(16, weight: .bold, relativeTo: .headline))
                            .foregroundStyle(Tokens.textPrimary)
                        Text(status.detail)
                            .font(AppFont.outfit(13, relativeTo: .subheadline))
                            .foregroundStyle(Tokens.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)

                divider

                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Tokens.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google account")
                            .font(AppFont.outfit(11.5, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(Tokens.textCaption)
                        Text(syncManager.email ?? "Signed in")
                            .font(AppFont.outfit(14.5, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(Tokens.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(Tokens.fill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Tokens.hairline, lineWidth: 1))

            if let action = status.action {
                Button(action.label) { action.run() }
                    .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Tokens.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Tokens.accent, in: Capsule())
                    .buttonStyle(PesolitaPressStyle())
            }

            Button { dismiss() } label: {
                Text("Done")
                    .font(AppFont.outfit(16, weight: .bold, relativeTo: .body))
                    .foregroundStyle(Tokens.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Tokens.fillRaised, in: Capsule())
            }
            .buttonStyle(PesolitaPressStyle())

            Button("Sign out of Google") { confirmingSignOut = true }
                .font(AppFont.outfit(13.5, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Tokens.negative)
                .frame(minHeight: 40)
                .alert("Sign out of Google?", isPresented: $confirmingSignOut) {
                    Button("Stay signed in", role: .cancel) {}
                    Button("Sign out", role: .destructive) {
                        Task { await syncManager.signOut() }
                    }
                } message: {
                    Text("Your wallet stays on this iPhone and your backup stays in the cloud. New changes won't back up until you sign in again. Pesolita Pro stays on.")
                }
            debugControls
        }
    }

    private struct Status {
        var symbol: String
        var tint: Color
        var tile: Color
        var title: String
        var detail: String
        var action: (label: String, run: () -> Void)?
    }

    private var status: Status {
        switch syncManager.phase {
        case .needsDecision:
            return Status(symbol: "exclamationmark.icloud.fill", tint: Tokens.accentText, tile: Tokens.accentTint,
                          title: "Two versions found", detail: "This iPhone and your backup differ. Choose what to keep — nothing is lost until you do.",
                          action: ("Review backup", { reviewBackup() }))
        case .paused(.unreachable):
            return Status(symbol: "icloud.slash.fill", tint: Tokens.negative, tile: Tokens.redTint,
                          title: "Couldn't connect", detail: "Nothing changed on either side. Check your connection and try again.",
                          action: ("Try again", { Task { await syncManager.retry(store) } }))
        case .paused(.notPro):
            return Status(symbol: "pause.circle.fill", tint: Tokens.accentText, tile: Tokens.accentTint,
                          title: "Paused", detail: "Pesolita Pro isn't on this Apple ID. Restore your purchase to keep backing up.",
                          action: ("Restore Purchases", { Task { await storeManager.restorePurchases() } }))
        case .reconciling:
            return Status(symbol: "icloud", tint: Tokens.textSecondary, tile: Tokens.fillRaised,
                          title: "Checking…", detail: "Comparing this iPhone with your backup.", action: nil)
        default:
            let when = syncManager.lastSyncTime.map { "Last saved \($0.formatted(.relative(presentation: .named)))" }
            return Status(symbol: "checkmark.icloud.fill", tint: Tokens.positive, tile: Tokens.greenTint,
                          title: syncManager.isSyncing ? "Saving…" : "Backup is on",
                          detail: when ?? "Changes save automatically.", action: nil)
        }
    }

    private func reviewBackup() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.openRestoreFlow() }
    }

    // MARK: Shared pieces

    private var backdrop: some View {
        ZStack(alignment: .top) {
            Tokens.bgBase
            LinearGradient(colors: [Tokens.accent.opacity(scheme == .dark ? 0.08 : 0.14), Tokens.accent.opacity(0)],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35))
            ScatteredPatternView()
        }
        .ignoresSafeArea()
    }

    private var divider: some View {
        Rectangle().fill(Tokens.hairline).frame(height: 1).padding(.leading, 72)
    }

    private func benefitRow(_ symbol: String, tint: Color, tile: Color, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.outfit(15.5, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(Tokens.textPrimary)
                Text(detail)
                    .font(AppFont.outfit(13, relativeTo: .subheadline))
                    .foregroundStyle(Tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func laterButton(_ label: String) -> some View {
        Button(label) { dismiss() }
            .font(AppFont.outfit(13.5, weight: .semibold, relativeTo: .footnote))
            .foregroundStyle(Tokens.textSecondary)
            .frame(minHeight: 40)
    }

    @ViewBuilder
    private var debugControls: some View {
        #if DEBUG
        if !StoreCapture.active {
        HStack(spacing: 16) {
            Button("Debug: grant Pro") { storeManager.debugSetPro(true) }
            Button("Debug: reset Pro") { storeManager.debugSetPro(false) }
        }
        .font(AppFont.outfit(11, relativeTo: .caption2))
        .foregroundStyle(Tokens.textTertiary)
        }
        #endif
    }

    private func celebrate() {
        showSparkles = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSparkles = false }
    }
}

private struct PromiseLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Tokens.positive)
            configuration.title
        }
    }
}

// MARK: - Background Pattern
struct ScatteredPatternView: View {
    let items = [
        // Kept to the corners around the mascot so nothing sits behind the text.
        ("pesetasign", CGPoint(x: 0.1, y: 0.07), 15.0),
        ("suit.spade.fill", CGPoint(x: 0.88, y: 0.06), -20.0),
        ("suit.spade.fill", CGPoint(x: 0.14, y: 0.17), 25.0),
        ("pesetasign", CGPoint(x: 0.86, y: 0.17), -30.0)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<items.count, id: \.self) { i in
                    Image(systemName: items[i].0)
                        .font(.system(size: 34))
                        .foregroundStyle(Tokens.textPrimary.opacity(0.045))
                        .rotationEffect(.degrees(items[i].2))
                        .position(
                            x: items[i].1.x * proxy.size.width,
                            y: items[i].1.y * proxy.size.height
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Sparkles Animation
struct SparklesView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: animate ? 24 : 0))
                    .foregroundStyle(Tokens.accentText)
                    .offset(x: animate ? .random(in: -80...80) : 0,
                            y: animate ? .random(in: -80...80) : 0)
                    .opacity(animate ? 0 : 1)
                    .rotationEffect(.degrees(animate ? 180 : 0))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animate = true
            }
        }
    }
}
