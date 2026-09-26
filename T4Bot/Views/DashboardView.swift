import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showStopConfirmation = false
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()
                ScrollView {
                    if let s = appModel.snapshot {
                        VStack(spacing: 14) {
                            hero(s)
                            if let a = s.account {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    MetricCard(title: "الرصيد", value: money(a.balance,a.currency), systemImage: "banknote.fill")
                                    MetricCard(title: "Equity", value: money(a.equity,a.currency), systemImage: "chart.line.uptrend.xyaxis", tint: .purple)
                                    MetricCard(title: "العائم", value: money(a.profit,a.currency), systemImage: "waveform.path.ecg", tint: a.profit >= 0 ? T4Palette.positive : T4Palette.negative)
                                    MetricCard(title: "المراكز", value: "\(s.positions.count) / \(s.engine.maxPositions)", systemImage: "square.stack.3d.up.fill", tint: .orange)
                                }
                            }
                            engine(s)
                            if !s.analysis.isEmpty { recentAnalysis(s.analysis) }
                        }.padding(16)
                    } else {
                        ContentUnavailableView("بانتظار الاتصال", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
            }
            .navigationTitle("T4Bot").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { connectionPill } }
            .refreshable { await appModel.refresh() }
            .loadingOverlay(appModel.isPerformingCommand)
            .confirmationDialog("إيقاف المحرك؟", isPresented: $showStopConfirmation, titleVisibility: .visible) {
                Button("إيقاف وإغلاق المراكز المتتبعة", role: .destructive) { Task { await appModel.stopEngine() } }
                Button("إلغاء", role: .cancel) {}
            }
        }
    }

    private func hero(_ s: ServerSnapshot) -> some View {
        HeroCard {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MT5 CONTROL").font(.caption2.bold()).opacity(0.75)
                        if let a=s.account {
                            Text("MT5 • \(a.login)").font(.title2.bold()).monospacedDigit()
                            Text(a.isDemo ? "حساب Demo" : "حساب Real").font(.caption).opacity(0.85)
                        } else { Text("MT5 غير متصل").font(.title2.bold()) }
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(.white.opacity(0.22), lineWidth: 8)
                        Circle().trim(from: 0, to: s.engine.running ? 0.82 : 0.18).stroke(T4Palette.accent2, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                        Image(systemName: s.engine.running ? "bolt.fill" : "pause.fill").font(.title3.bold())
                    }.frame(width: 68, height: 68)
                }
                HStack(spacing: 8) {
                    heroStatus(marketOpen(s) ? "السوق مفتوح" : "السوق مغلق", marketOpen(s))
                    heroStatus(s.engine.running ? "المحرك مفعل" : "المحرك معطل", s.engine.running)
                    Spacer()
                    Text("\(s.settings.symbols.count) أزواج").font(.caption.bold()).opacity(0.85)
                }
            }
        }
    }

    private func engine(_ s: ServerSnapshot) -> some View {
        SurfaceCard {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("المحرك").font(.headline)
                        Text(s.settings.symbols.isEmpty ? "لا توجد أزواج نشطة" : s.settings.symbols.joined(separator: " • "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    StatusPill(title: s.engine.running ? "مفعل" : "معطل", isPositive: s.engine.running)
                }
                Button {
                    if s.engine.running { showStopConfirmation=true } else { Task { await appModel.startEngine() } }
                } label: {
                    Label(s.engine.running ? "إيقاف المحرك" : "تشغيل المحرك", systemImage: s.engine.running ? "stop.fill" : "play.fill")
                        .fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 9)
                }.buttonStyle(.borderedProminent).tint(s.engine.running ? T4Palette.negative : T4Palette.accent)
            }
        }
    }

    private func recentAnalysis(_ rows:[AnalysisSnapshot]) -> some View {
        SurfaceCard {
            VStack(spacing: 12) {
                SectionHeader("آخر تحليل", subtitle: "الأزواج النشطة فقط")
                ForEach(rows.prefix(4)) { x in
                    HStack {
                        Text(x.symbol).font(.subheadline.bold())
                        Spacer()
                        Text(x.state == "signal" ? (x.side == "BUY" ? "شراء" : "بيع") : "انتظار").font(.caption.bold())
                            .foregroundStyle(x.state == "signal" ? T4Palette.positive : .secondary)
                    }
                }
            }
        }
    }

    private func heroStatus(_ title:String,_ on:Bool)->some View {
        HStack(spacing:5){ Circle().fill(on ? T4Palette.accent2 : .white.opacity(0.55)).frame(width:7,height:7); Text(title).font(.caption2.bold()) }
            .padding(.horizontal,9).padding(.vertical,7).background(.white.opacity(0.13),in:Capsule())
    }

    private func marketOpen(_ s:ServerSnapshot)->Bool {
        guard s.readiness.connected else { return false }
        let c=Calendar(identifier:.gregorian), now=Date()
        let w=c.component(.weekday,from:now)
        if w == 1 || w == 7 { return false }
        let h=c.component(.hour,from:now), m=c.component(.minute,from:now)
        return !((h == 23 && m >= 45) || (h == 0 && m < 30))
    }
    private var connectionPill:some View {
        StatusPill(title: appModel.connectionState == .live ? "مباشر" : "يتصل", isPositive: appModel.connectionState == .live)
    }
    private func money(_ v:Double,_ c:String)->String { v.formatted(.currency(code:c.isEmpty ? "USD":c)) }
}
