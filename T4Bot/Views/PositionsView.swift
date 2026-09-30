import SwiftUI

struct PositionsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var segment: Segment = .open

    enum Segment: String, CaseIterable, Identifiable {
        case open = "المفتوحة"
        case history = "السجل"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            AppBackdrop()
            VStack(spacing: 0) {
                Picker("الصفقات", selection: $segment) {
                    ForEach(Segment.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(16)

                switch segment {
                case .open: openPositions
                case .history: history
                }
            }
        }
        .navigationTitle("الصفقات")
        .navigationBarTitleDisplayMode(.inline)
        .task { await appModel.loadHistory(silent: true) }
    }

    @ViewBuilder
    private var openPositions: some View {
        let positions = appModel.snapshot?.positions ?? []
        if positions.isEmpty {
            ContentUnavailableView("لا توجد صفقات مفتوحة", systemImage: "tray", description: Text("عند تنفيذ صفقة ستظهر هنا مباشرة."))
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(positions) { p in
                        Panel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(p.symbol).font(.title3.bold().monospaced())
                                        Text([p.strategy, p.regime].compactMap{$0}.joined(separator: " • "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(p.side)
                                            .font(.caption.bold())
                                            .foregroundStyle(p.side == "BUY" ? T4Palette.positive : T4Palette.negative)
                                        Text(money(p.profit))
                                            .font(.headline.monospacedDigit())
                                            .foregroundStyle(p.profit >= 0 ? T4Palette.positive : T4Palette.negative)
                                    }
                                }

                                Divider()

                                HStack {
                                    metric("الحجم", p.volume.formatted(.number.precision(.fractionLength(2))))
                                    metric("الدخول", price(p.priceOpen))
                                    metric("الحالي", price(p.priceCurrent))
                                }

                                HStack {
                                    metric("SL", price(p.sl))
                                    metric("TP", price(p.tp))
                                    metric("المخاطرة", p.riskPct.map { String(format: "%.2f%%", $0) } ?? "—")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        if appModel.tradeHistory.isEmpty {
            ContentUnavailableView("لا يوجد سجل بعد", systemImage: "clock.arrow.circlepath")
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    summary
                    ForEach(appModel.tradeHistory.sorted { $0.closedAt > $1.closedAt }.prefix(100)) { trade in
                        Panel {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(trade.symbol).font(.headline.monospaced())
                                        Text([trade.strategy, trade.regime].compactMap{$0}.joined(separator: " • "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(money(trade.pnl))
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(trade.pnl >= 0 ? T4Palette.positive : T4Palette.negative)
                                }
                                HStack {
                                    Text(trade.reason.isEmpty ? trade.result : trade.reason)
                                    Spacer()
                                    if let r = trade.rMultiple {
                                        Text(String(format: "%.2fR", r))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var summary: some View {
        let net = appModel.tradeHistory.reduce(0) { $0 + $1.pnl }
        let wins = appModel.tradeHistory.filter { $0.pnl > 0 }.count
        let losses = appModel.tradeHistory.filter { $0.pnl < 0 }.count
        return HStack(spacing: 10) {
            MetricTile(title: "الصافي", value: money(net), subtitle: nil, icon: "sum", tint: net >= 0 ? T4Palette.positive : T4Palette.negative)
            MetricTile(title: "فوز", value: "\(wins)", subtitle: nil, icon: "arrow.up.right", tint: T4Palette.positive)
            MetricTile(title: "خسارة", value: "\(losses)", subtitle: nil, icon: "arrow.down.right", tint: T4Palette.negative)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func money(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func price(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2...6)))
    }
}
