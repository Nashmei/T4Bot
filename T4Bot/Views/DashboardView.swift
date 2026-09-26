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
                                    AccountRingMetric(title:"الرصيد", value:money(a.balance,a.currency), progress:a.equity > 0 ? a.marginFree/a.equity : 0, icon:"banknote.fill", detail:"الهامش الحر")
                                    AccountRingMetric(title:"Equity", value:money(a.equity,a.currency), progress:a.balance > 0 ? a.equity/a.balance : 0, icon:"chart.line.uptrend.xyaxis", detail:"مقارنة بالرصيد", tint:.purple)
                                    AccountRingMetric(title:"العائم", value:money(a.profit,a.currency), progress:a.balance > 0 ? abs(a.profit)/a.balance : 0, icon:"waveform.path.ecg", detail:a.profit >= 0 ? "ربح عائم" : "خسارة عائمة", tint:a.profit >= 0 ? T4Palette.positive:T4Palette.negative)
                                    AccountRingMetric(title:"المراكز", value:"\(s.positions.count) / \(s.engine.maxPositions)", progress:s.engine.maxPositions > 0 ? Double(s.positions.count)/Double(s.engine.maxPositions):0, icon:"square.stack.3d.up.fill", detail:"المستخدم من الحد", tint:.orange)
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
            .loadingOverlay(appModel.isPerformingCommand)
            .sheet(isPresented:$showStopConfirmation) {
                StopEngineSheet {
                    showStopConfirmation=false
                    Task { await appModel.stopEngine() }
                }
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
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
                            Text("MT5 • " + String(a.login)).font(.title2.bold()).monospacedDigit()
                            Text(a.isDemo ? "حساب Demo" : "حساب Real").font(.caption).opacity(0.85)
                        } else { Text("MT5 غير متصل").font(.title2.bold()) }
                    }
                    Spacer()
                    BrandMark(size: 68, running: s.engine.running)
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
        Text(appModel.connectionState == .live ? "مباشر" : "يتصل")
            .font(.caption.bold())
            .foregroundStyle(appModel.connectionState == .live ? T4Palette.positive : .secondary)
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityAddTraits(.isStaticText)
    }
    private func money(_ v:Double,_ c:String)->String { v.formatted(.currency(code:c.isEmpty ? "USD":c)) }
}


private struct StopEngineSheet:View {
    let confirm:()->Void
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(spacing:18) {
            Capsule().fill(.secondary.opacity(0.25)).frame(width:38,height:5)
            Image(systemName:"stop.circle.fill").font(.system(size:42)).foregroundStyle(T4Palette.negative)
            VStack(spacing:5){Text("إيقاف المحرك؟").font(.title3.bold());Text("سيتم إيقاف التداول وإغلاق المراكز المتتبعة.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)}
            HStack { Button("إلغاء"){dismiss()}.buttonStyle(.bordered).frame(maxWidth:.infinity); Button("إيقاف",role:.destructive){confirm()}.buttonStyle(.borderedProminent).tint(T4Palette.negative).frame(maxWidth:.infinity) }
        }.padding(22)
    }
}
