import SwiftUI
import UIKit

struct PositionsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selection: Segment = .open

    enum Segment: String, CaseIterable, Identifiable {
        case open = "مفتوحة"
        case history = "السجل"

        var id: String { rawValue }
    }

    private var currency: String {
        let value = appModel.snapshot?.account?.currency ?? "USD"
        return value.isEmpty ? "USD" : value
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("الصفقات", selection: $selection) {
                    Text("مفتوحة \(appModel.snapshot?.positions.count ?? 0)")
                        .tag(Segment.open)
                    Text("السجل \(appModel.tradeHistory.count)")
                        .tag(Segment.history)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)

                Group {
                    switch selection {
                    case .open:
                        openPositions
                    case .history:
                        history
                    }
                }
            }
            .navigationTitle("الصفقات")
            .refreshable {
                await appModel.refresh(silent: true)
                await appModel.loadHistory(silent: true)
            }
        }
    }

    @ViewBuilder
    private var openPositions: some View {
        if let positions = appModel.snapshot?.positions, !positions.isEmpty {
            List(positions) { position in
                NavigationLink {
                    TradeDetailView(
                        title: "\(position.symbol) • \(position.side)",
                        ticket: position.ticket,
                        imageID: position.imageId,
                        rows: [
                            ("الحجم", position.volume.formatted(.number.precision(.fractionLength(2)))),
                            ("الدخول", position.priceOpen.formatted(.number.precision(.fractionLength(2...6)))),
                            ("الحالي", position.priceCurrent.formatted(.number.precision(.fractionLength(2...6)))),
                            ("SL", position.sl.formatted(.number.precision(.fractionLength(2...6)))),
                            ("TP", position.tp.formatted(.number.precision(.fractionLength(2...6)))),
                            ("PnL", money(position.profit))
                        ]
                    )
                } label: {
                    PositionRow(position: position, currency: currency)
                }
            }
            .listStyle(.plain)
        } else {
            ContentUnavailableView(
                "لا توجد مراكز مفتوحة",
                systemImage: "tray",
                description: Text("أي صفقة تُغلق ستبقى محفوظة في تبويب السجل مع نتيجتها.")
            )
        }
    }

    @ViewBuilder
    private var history: some View {
        if appModel.tradeHistory.isEmpty {
            ContentUnavailableView(
                "لا يوجد سجل بعد",
                systemImage: "clock.arrow.circlepath",
                description: Text("ستظهر هنا نتائج الصفقات المغلقة مع سبب الإغلاق والربح أو الخسارة.")
            )
        } else {
            List {
                Section {
                    HStack(spacing: 10) {
                        HistoryMetric(
                            title: "الصافي",
                            value: money(appModel.tradeHistory.reduce(0) { $0 + $1.pnl }),
                            positive: appModel.tradeHistory.reduce(0) { $0 + $1.pnl } >= 0
                        )
                        HistoryMetric(
                            title: "ربح",
                            value: "\(appModel.tradeHistory.filter { $0.pnl > 0 }.count)",
                            positive: true
                        )
                        HistoryMetric(
                            title: "خسارة",
                            value: "\(appModel.tradeHistory.filter { $0.pnl < 0 }.count)",
                            positive: false
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("آخر الصفقات") {
                    ForEach(appModel.tradeHistory) { trade in
                        NavigationLink {
                            TradeDetailView(
                                title: "\(trade.symbol) • \(trade.side)",
                                ticket: trade.ticket,
                                imageID: trade.imageId,
                                rows: [
                                    ("الاستراتيجية", trade.strategy.isEmpty ? "—" : trade.strategy),
                                    ("الحجم", trade.volume.formatted(.number.precision(.fractionLength(2)))),
                                    ("الدخول", trade.entry.formatted(.number.precision(.fractionLength(2...6)))),
                                    ("الخروج", trade.exit.formatted(.number.precision(.fractionLength(2...6)))),
                                    ("SL", trade.sl.formatted(.number.precision(.fractionLength(2...6)))),
                                    ("TP", trade.tp.formatted(.number.precision(.fractionLength(2...6)))),
                                    ("النتيجة", displayResult(trade)),
                                    ("PnL", money(trade.pnl))
                                ]
                            )
                        } label: {
                            ClosedTradeRow(trade: trade, currency: currency)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func displayResult(_ trade: ClosedTrade) -> String {
        if !trade.reason.isEmpty {
            return trade.reason
        }

        switch trade.result {
        case "TP": return "TP 🎯"
        case "SL": return "SL 🛑"
        case "POSITION_CLOSED": return "إغلاق 🏁"
        default: return trade.result.isEmpty ? "—" : trade.result
        }
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: currency).sign(strategy: .always()))
    }
}

private struct HistoryMetric: View {
    let title: String
    let value: String
    let positive: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(positive ? .green : .red)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PositionRow: View {
    let position: PositionSnapshot
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: position.side == "BUY" ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .font(.title2)
                .foregroundStyle(position.side == "BUY" ? .green : .red)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(position.symbol)
                        .font(.headline)

                    Text(position.side)
                        .font(.caption.bold())
                        .foregroundStyle(position.side == "BUY" ? .green : .red)
                }

                Text("Ticket \(position.ticket) • \(position.volume.formatted(.number.precision(.fractionLength(2)))) lot")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(position.profit, format: .currency(code: currency).sign(strategy: .always()))
                .font(.headline.monospacedDigit())
                .foregroundStyle(position.profit >= 0 ? .green : .red)
        }
        .padding(.vertical, 5)
    }
}

private struct ClosedTradeRow: View {
    let trade: ClosedTrade
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trade.pnl >= 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(trade.pnl >= 0 ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(trade.symbol)
                        .font(.headline)

                    Text(trade.side)
                        .font(.caption.bold())
                        .foregroundStyle(trade.side == "BUY" ? .green : .red)
                }

                Text(trade.strategy.isEmpty ? trade.result : "\(trade.strategy) • \(trade.result)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.pnl, format: .currency(code: currency).sign(strategy: .always()))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(trade.pnl >= 0 ? .green : .red)

                Text(Date(timeIntervalSince1970: trade.closedAt), style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct TradeDetailView: View {
    @EnvironmentObject private var appModel: AppModel

    let title: String
    let ticket: Int64
    let imageID: String?
    let rows: [(String, String)]

    @State private var imageData: Data?
    @State private var imageLoadFinished = false

    var body: some View {
        List {
            if let imageData, let image = UIImage(data: imageData) {
                Section("صورة الصفقة") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .listRowInsets(EdgeInsets())
                }
            } else if imageID != nil && !imageLoadFinished {
                Section("صورة الصفقة") {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }

            Section("تفاصيل الصفقة") {
                LabeledContent("Ticket", value: String(ticket))

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    LabeledContent(row.0, value: row.1)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: imageID) {
            defer { imageLoadFinished = true }
            guard let imageID else { return }
            imageData = await appModel.tradeImage(mediaID: imageID)
        }
    }
}
