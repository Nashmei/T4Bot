import SwiftUI
import UIKit

struct PositionsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selection: Segment = .open
    @State private var historyFilter: HistoryFilter = .all

    enum HistoryFilter { case all, wins, losses }

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
        case .all: return latest
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
                            positive: appModel.tradeHistory.reduce(0) { $0 + $1.pnl } >= 0,
                            selected: historyFilter == .all
                        ) { historyFilter = .all }
                        HistoryMetric(
                            title: "ربح",
                            value: "\(appModel.tradeHistory.filter { $0.pnl > 0 }.count)",
                            positive: true,
                            selected: historyFilter == .wins
                        ) { historyFilter = .wins }
                        HistoryMetric(
                            title: "خسارة",
                            value: "\(appModel.tradeHistory.filter { $0.pnl < 0 }.count)",
                            positive: false,
                            selected: historyFilter == .losses
                        ) { historyFilter = .losses }
                    }
                    .listRowInsets(EdgeInsets())
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
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .background(
            selected ? T4Palette.accent.opacity(0.07) : Color.primary.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(alignment:.bottom) {
            if selected {
                Capsule()
                    .fill(T4Palette.accent)
                    .frame(width:28,height:3)
                    .padding(.bottom,5)
            }
        }
        }.buttonStyle(.plain)
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
    let title:String; let ticket:Int64; let imageID:String?; let rows:[(String,String)]
    @State private var imageData:Data?
    @State private var imageLoadFinished=false
    @State private var fullScreen=false

    var body:some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(spacing:16) {
                    if let imageData,let image=UIImage(data:imageData) {
                        SurfaceCard {
                            VStack(alignment:.leading,spacing:12) {
                                HStack { Text("صورة الصفقة").font(.headline); Spacer(); Button {fullScreen=true} label:{Label("تكبير",systemImage:"arrow.up.left.and.arrow.down.right")} .font(.caption.bold()) }
                                Button {fullScreen=true} label:{
                                    Image(uiImage:image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:18))
                                }.buttonStyle(.plain)
                            }
                        }
                    } else if imageID != nil && !imageLoadFinished {
                        SurfaceCard { HStack {Spacer();ProgressView();Spacer()}.padding(.vertical,60) }
                    }
                    SurfaceCard {
                        VStack(spacing:0) {
                            detailRow("Ticket",String(ticket))
                            ForEach(Array(rows.enumerated()),id: \.offset){i,row in
                                Divider().opacity(0.5); detailRow(row.0,row.1)
                            }
                        }
                    }
                    ShareLink(item: shareText) {
                        Label("مشاركة تفاصيل الصفقة",systemImage:"square.and.arrow.up").fontWeight(.bold).frame(maxWidth:.infinity).padding(.vertical,10)
                    }.buttonStyle(.borderedProminent).tint(T4Palette.accent)
                }.padding(16)
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.topBarTrailing){ShareLink(item:shareText){Image(systemName:"square.and.arrow.up")}} }
        .task(id:imageID){defer{imageLoadFinished=true};guard let imageID else{return};imageData=await appModel.tradeImage(mediaID:imageID)}
        .fullScreenCover(isPresented:$fullScreen) {
            if let imageData,let image=UIImage(data:imageData){TradeImageFullScreen(image:image)}
        }
    }
    private func detailRow(_ key:String,_ value:String)->some View {
        HStack(alignment:.firstTextBaseline){Text(key).font(.subheadline.weight(.semibold));Spacer();Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).multilineTextAlignment(.leading)}
            .padding(.vertical,13)
    }
    private var shareText:String {
        var text = "\(title)\nTicket: \(ticket)"
        for r in rows {
            text += "\n\(r.0): \(r.1)"
        }
        return text
    }
}

private struct TradeImageFullScreen:View {
    let image:UIImage
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage:image).resizable().scaledToFit().padding(.vertical,50)
            VStack { HStack {Spacer();Button {dismiss()} label:{Image(systemName:"xmark").font(.headline.bold()).foregroundStyle(.white).frame(width:44,height:44).background(.ultraThinMaterial,in:Circle())}.padding()};Spacer() }
        }
    }
}
