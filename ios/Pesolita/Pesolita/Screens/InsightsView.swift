import SwiftUI

struct InsightsView: View {
    @Bindable var store: WalletStore
    @State private var period: InsightPeriod = .week

    private var transactions: [Transaction] { WalletMetrics.transactions(store.snapshot.tx, period: period) }
    private var totals: [CategoryTotal] { WalletMetrics.categoryTotals(store.snapshot.tx, period: period) }
    private var biggest: Transaction? { transactions.filter { $0.amount < 0 }.max { abs($0.amount) < abs($1.amount) } }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            statCard(
                                "LOGGED \(period.label.uppercased())",
                                value: "\(transactions.count)",
                                subtitle: transactions.count == 1 ? "transaction" : "transactions",
                                dark: true
                            )
                            statCard(
                                "BIGGEST SINGLE HIT",
                                value: biggest.map { MoneyFormat.balance(abs($0.amount)) } ?? "₱0",
                                subtitle: biggest?.merchant ?? "nothing logged yet",
                                dark: false
                            )
                        }

                        Text("Where it went")
                            .font(AppFont.outfit(15, weight: .bold, relativeTo: .headline))
                            .foregroundStyle(Tokens.ink)
                            .padding(.top, 22)

                        if totals.isEmpty { emptyBreakdown }
                        else { categoryBreakdown }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 112)
                }
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Button { store.selectTab(.home) } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Tokens.dark3, in: Circle())
                }
                Spacer()
                Text("Insights").font(AppFont.outfit(14, weight: .semibold, relativeTo: .subheadline))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }

            HStack(spacing: 2) {
                ForEach(InsightPeriod.allCases) { option in
                    Button {
                        period = option
                        FeedbackCenter.selectionChanged()
                    } label: {
                        Text(option.label)
                            .font(AppFont.outfit(12.5, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(period == option ? Tokens.ink : .white.opacity(0.6))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(period == option ? Tokens.accent : .clear, in: Capsule())
                    }
                    .buttonStyle(PesolitaPressStyle())
                }
            }
            .padding(3)
            .frame(height: 38)
            .background(.white.opacity(0.1), in: Capsule())
            .padding(.top, 14)

            insightCard.padding(.top, 18)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 22)
        .background(Tokens.ink, in: UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
    }

    private var insightCard: some View {
        let copy = insightCopy
        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Tokens.ink.opacity(0.1))
                .frame(width: 132, height: 132)
                .offset(x: 30, y: -34)
            VStack(alignment: .leading, spacing: 0) {
                Text(kicker)
                    .font(AppFont.outfit(10.5, weight: .semibold, relativeTo: .caption2)).tracking(1.25).foregroundStyle(Tokens.ink.opacity(0.5))
                Text(copy.head)
                    .font(AppFont.outfit(22, weight: .black, relativeTo: .title2)).tracking(-0.7).foregroundStyle(Tokens.ink).padding(.top, 8)
                Text(copy.body)
                    .font(AppFont.outfit(12.5, relativeTo: .caption)).foregroundStyle(Tokens.ink.opacity(0.66)).lineSpacing(2.5).padding(.top, 8).frame(maxWidth: 255, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
        }
        .frame(minHeight: 160)
        .background(Tokens.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var insightCopy: PeriodInsight {
        if transactions.isEmpty {
            let suffix = period == .week ? "the last 7 days" : period == .month ? "the last 30 days" : "yet"
            return PeriodInsight(
                head: period == .week ? "A quiet week" : period == .month ? "A quiet month" : "A clean slate",
                body: "Nothing logged \(suffix). Either you spent nothing, or you owe your future self some typing."
            )
        }
        return WalletMetrics.insight(store.snapshot.tx, period: period)
    }

    private var kicker: String { period == .week ? "WEEKLY READ" : period == .month ? "MONTHLY READ" : "ALL-TIME READ" }

    private func statCard(_ label: String, value: String, subtitle: String, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(AppFont.outfit(10.5, weight: .medium, relativeTo: .caption2)).tracking(0.95)
                .foregroundStyle(dark ? .white.opacity(0.45) : Tokens.muted2)
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(value)
                .font(AppFont.outfit(21, weight: .bold, relativeTo: .title3)).tracking(-0.6)
                .foregroundStyle(dark ? .white : Tokens.ink).padding(.top, 8).lineLimit(1).minimumScaleFactor(0.65)
            Text(subtitle)
                .font(AppFont.outfit(11, relativeTo: .caption)).foregroundStyle(dark ? .white.opacity(0.45) : Tokens.muted2)
                .padding(.top, 5).lineLimit(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 89, alignment: .leading)
        .background(dark ? Tokens.ink : Tokens.sand1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyBreakdown: some View {
        VStack(spacing: 0) {
            if store.snapshot.tx.isEmpty {
                SpriteAnimationView(spec: .idleSteady, size: 88)
                    .frame(width: 88, height: 88)
                    .padding(.bottom, 8)
                Text("Nothing logged yet.")
                    .font(AppFont.outfit(15, weight: .bold, relativeTo: .subheadline)).foregroundStyle(Tokens.ink)
                Text("Once you start logging, this shows where it actually goes.")
                    .font(AppFont.outfit(12.5, relativeTo: .caption)).foregroundStyle(Tokens.muted2).padding(.top, 5)
            } else {
                Text(transactions.isEmpty ? "Nothing logged \(period.label.lowercased()). Try a wider period, or log a spend." : "Only money coming in so far. Log a spend and this fills in.")
                    .font(AppFont.outfit(12.5, relativeTo: .caption)).foregroundStyle(Tokens.muted2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, store.snapshot.tx.isEmpty ? 18 : 30)
        .background(Tokens.sand1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 14)
    }

    private var categoryBreakdown: some View {
        let maxAmount = max(1, totals.first?.amount ?? 1)
        return VStack(spacing: 14) {
            ForEach(Array(totals.enumerated()), id: \.element.id) { index, total in
                VStack(spacing: 7) {
                    HStack {
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: total.category.colorHex)).frame(width: 9, height: 9)
                            Text(total.category.rawValue).font(AppFont.outfit(13, weight: .semibold, relativeTo: .subheadline))
                        }
                        Spacer()
                        Text(MoneyFormat.balance(total.amount)).font(AppFont.outfit(12.5, weight: .semibold, relativeTo: .caption)).foregroundStyle(Tokens.muted1)
                    }
                    GeometryReader { proxy in
                        Capsule().fill(Tokens.line1)
                        Capsule().fill(Color(hex: total.category.colorHex)).frame(width: proxy.size.width * total.amount / maxAmount)
                            .animation(Tokens.easeOut(0.75).delay(Double(index) * 0.06), value: period)
                    }
                    .frame(height: 9)
                }
            }
        }
        .foregroundStyle(Tokens.ink)
        .padding(.top, 12)
    }
}
