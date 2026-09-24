import SwiftUI

struct PositionsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selection: Segment = .open

    enum Segment: String, CaseIterable, Identifiable {
        case open = "مفتوحة"
        case history = "السجل"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("الصفقات", selection: $selection) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

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
                await appModel.loadHistory()
            }
        }
    }

    @ViewBuilder
    private var openPositions: some View {
        if let positions = appModel.snapshot?.positions, !positions.isEmpty {
            List(positions) { position in
                NavigationLink {
                    TradeDetailView(
                        title: "(position.symbol) • (position.side)",
                        ticket: position.ticket,
                        imageID: position.imageId,
                        rows: [
                            ("Volume", position.volume.formatted(.number.precision(.fractionLength(2)))),
                            ("Entry", position.priceOpen.formatted()),
                            ("Current", position.priceCurrent.formatted()),
                            ("SL", position.sl.formatted()),
                            ("TP", position.tp.formatted()),
                            ("PnL", money(position.profit))
                        ]
                    )
                } label: {
                    PositionRow(position: position)
                }
            }
            .listStyle(.plain)
        } else {
            ContentUnavailableView(
                "لا توجد مراكز مفتوحة",
                systemImage: "tray",
                description: Text("الصفقات التي تُغلق تنتقل تلقائياً إلى السجل.")
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
            List(appModel.tradeHistory) { trade in
                NavigationLink {
                    TradeDetailView(
                        title: "(trade.symbol) • (trade.side)",
                        ticket: trade.ticket,
                        imageID: trade.imageId,
                        rows: [
                            ("الاستراتيجية", trade.strategy.isEmpty ? "—" : trade.strategy),
                            ("Volume", trade.volume.formatted(.number.precision(.fractionLength(2)))),
                            ("Entry", trade.entry.formatted()),
                            ("Exit", trade.exit.formatted()),
                            ("SL", trade.sl.formatted()),
                            ("TP", trade.tp.formatted()),
                            ("النتيجة", trade.result),
                            ("PnL", money(trade.pnl))
                        ]
                    )
                } label: {
                    ClosedTradeRow(trade: trade)
                }
            }
            .listStyle(.plain)
        }
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: appModel.snapshot?.account?.currency ?? "USD").sign(strategy: .always()))
    }
}

private struct PositionRow: View {
    let position: PositionSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: position.side == "BUY" ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .font(.title2)
                .foregroundStyle(position.side == "BUY" ? .green : .red)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(position.symbol).font(.headline)
                    Text(position.side)
                        .font(.caption.bold())
                        .foregroundStyle(position.side == "BUY" ? .green : .red)
                }
                Text("Ticket (position.ticket) • (position.volume.formatted(.number.precision(.fractionLength(2)))) lot")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(position.profit, format: .currency(code: "USD").sign(strategy: .always()))
                .font(.headline.monospacedDigit())
                .foregroundStyle(position.profit >= 0 ? .green : .red)
        }
        .padding(.vertical, 5)
    }
}

private struct ClosedTradeRow: View {
    let trade: ClosedTrade

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trade.pnl >= 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(trade.pnl >= 0 ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.symbol).font(.headline)
                    Text(trade.side)
                        .font(.caption.bold())
                        .foregroundStyle(trade.side == "BUY" ? .green : .red)
                }
                Text(trade.strategy.isEmpty ? trade.result : "(trade.strategy) • (trade.result)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.pnl, format: .currency(code: "USD").sign(strategy: .always()))
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

    var body: some View {
        List {
            if let imageData, let image = UIImage(data: imageData) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .listRowInsets(EdgeInsets())
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
            guard let imageID else { return }
            imageData = await appModel.tradeImage(mediaID: imageID)
        }
    }
}
