import SwiftUI
import UIKit

struct PositionsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selection: Segment = .open
    @State private var historyFilter: HistoryFilter = .recent

    enum HistoryFilter: String, CaseIterable, Identifiable { case recent = "الأخيرة", wins = "الرابحة", losses = "الخاسرة"; var id: String { rawValue } }

    enum Segment: String, CaseIterable, Identifiable {
        case open = "مفتوحة"
        case history = "السجل"
        var id: String { rawValue }
    }

    private var currency: String {
        let value = appModel.snapshot?.account?.currency ?? "USD"
        return value.isEmpty ? "USD" : value
    }



    private var filteredHistory: [ClosedTrade] {
        let latest = Array(appModel.tradeHistory.sorted { $0.closedAt > $1.closedAt }.prefix(50))
        switch historyFilter {
        case .recent: return latest
        case .wins: return latest.filter { $0.pnl > 0 }
        case .losses: return latest.filter { $0.pnl < 0 }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                VStack(spacing: 0) {
                    Picker("الصفقات", selection: $selection) {
                        Text("مفتوحة \(appModel.snapshot?.positions.count ?? 0)")
                            .tag(Segment.open)
                        Text("السجل \(appModel.tradeHistory.count)")
                            .tag(Segment.history)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                    Group {
                        switch selection {
                        case .open:
                            openPositions
                        case .history:
                            history
                        }
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
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .t4ListBackground()
        } else {
            ContentUnavailableView(
                "لا توجد مراكز مفتوحة",
                systemImage: "tray",
                description: Text("أي صفقة تُغلق ستبقى محفوظة في السجل.")
            )
        }
    }

    @ViewBuilder
    private var history: some View {
        if appModel.tradeHistory.isEmpty {
            ContentUnavailableView(
                "لا يوجد سجل بعد",
                systemImage: "clock.arrow.circlepath",
                description: Text("ستظهر هنا نتائج الصفقات المغلقة.")
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

                Section {
                    Picker("فلترة السجل", selection: $historyFilter) { ForEach(HistoryFilter.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                }

                Section("آخر 50 صفقة") {
                    ForEach(filteredHistory) { trade in
                        NavigationLink {
                            TradeDetailView(
                                title: "\(trade.symbol) • \(trade.side)",
                                ticket: trade.ticket,
                                imageID: trade.imageId,
                                rows: [
                                    ("الاستراتيجية", readable(trade.strategy)),
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
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .t4ListBackground()
        }
    }

    private func displayResult(_ trade: ClosedTrade) -> String {
        if !trade.reason.isEmpty { return readable(trade.reason) }
        switch trade.result {
        case "TP": return "هدف الربح"
        case "SL": return "وقف الخسارة"
        case "PROTECTED_EXIT": return "حماية ربح"
        case "TRAILING_EXIT": return "Trailing"
        case "BREAKEVEN_EXIT": return "تعادل"
        case "MAX_DURATION_EXIT": return "انتهاء المدة"
        case "POSITION_CLOSED": return "إغلاق"
        default: return trade.result.isEmpty ? "—" : readable(trade.result)
        }
    }

    private func readable(_ raw: String) -> String {
        raw.isEmpty ? "—" : raw.replacingOccurrences(of: "_", with: " ")
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
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}

private struct PositionRow: View {
    let position: PositionSnapshot
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((position.side == "BUY" ? Color.green : Color.red).opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: position.side == "BUY" ? "arrow.up.right" : "arrow.down.right")
                    .font(.headline.bold())
                    .foregroundStyle(position.side == "BUY" ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(position.symbol)
                        .font(.headline)
                    Text(position.side == "BUY" ? "شراء" : "بيع")
                        .font(.caption.bold())
                        .foregroundStyle(position.side == "BUY" ? .green : .red)
                }

                Text("\(position.volume.formatted(.number.precision(.fractionLength(2)))) lot")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(position.profit, format: .currency(code: currency).sign(strategy: .always()))
                .font(.headline.monospacedDigit())
                .foregroundStyle(position.profit >= 0 ? .green : .red)
        }
        .padding(.vertical, 7)
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

                    Text(trade.side == "BUY" ? "شراء" : "بيع")
                        .font(.caption.bold())
                        .foregroundStyle(trade.side == "BUY" ? .green : .red)
                }

                Text(trade.strategy.isEmpty ? trade.result : trade.strategy.replacingOccurrences(of: "_", with: " "))
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
        .padding(.vertical, 7)
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

            Section("التفاصيل") {
                LabeledContent("Ticket", value: String(ticket))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    LabeledContent(row.0, value: row.1)
                }
            }
        }
        .t4ListBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: imageID) {
            defer { imageLoadFinished = true }
            guard let imageID else { return }
            imageData = await appModel.tradeImage(mediaID: imageID)
        }
    }
}
