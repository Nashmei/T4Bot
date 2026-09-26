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
                            connectionStatus
                            hero(s)

                            if let a = s.account {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    AccountRingMetric(
                                        title:"الرصيد",
                                        value:money(a.balance,a.currency),
                                        progress:a.equity > 0 ? a.marginFree/a.equity : 0,
                                        icon:"banknote.fill",
                                        detail:"الهامش الحر"
                                    )
                                    AccountRingMetric(
                                        title:"Equity",
                                        value:money(a.equity,a.currency),
                                        progress:a.balance > 0 ? a.equity/a.balance : 0,
                                        icon:"chart.line.uptrend.xyaxis",
                                        detail:"مقارنة بالرصيد",
                                        tint:T4Palette.accent
                                    )
                                    AccountRingMetric(
                                        title:"العائم",
                                        value:money(a.profit,a.currency),
                                        progress:a.balance > 0 ? abs(a.profit)/a.balance : 0,
                                        icon:"waveform.path.ecg",
                                        detail:a.profit >= 0 ? "ربح عائم" : "خسارة عائمة",
                                        tint:a.profit >= 0 ? T4Palette.positive:T4Palette.negative
                                    )
                                    AccountRingMetric(
                                        title:"المراكز",
                                        value:"\(s.positions.count) / \(s.engine.maxPositions)",
                                        progress:s.engine.maxPositions > 0 ? Double(s.positions.count)/Double(s.engine.maxPositions):0,
                                        icon:"square.stack.3d.up.fill",
                                        detail:"المستخدم من الحد",
                                        tint:.orange
                                    )
                                }
                            }

                            if s.settings.sessionProfitLimit > 0 {
                                sessionGoal(s)
                            }

                            engine(s)

                            if !s.analysis.isEmpty {
                                recentAnalysis(s.analysis)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    } else {
                        VStack(spacing: 14) {
                            connectionStatus
                            ContentUnavailableView(
                                "بانتظار الاتصال",
                                systemImage: "antenna.radiowaves.left.and.right"
                            )
                        }
                        .padding(16)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("T4Bot")
            .navigationBarTitleDisplayMode(.inline)
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

    private var connectionStatus: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(appModel.connectionState == .live ? T4Palette.positive : Color.secondary.opacity(0.6))
                .frame(width: 7, height: 7)
            Text(appModel.connectionState == .live ? "مباشر" : "يتصل")
                .font(.caption.weight(.semibold))
                .foregroundStyle(appModel.connectionState == .live ? T4Palette.positive : .secondary)
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private func hero(_ s: ServerSnapshot) -> some View {
        HeroCard {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MT5 CONTROL").font(.caption2.bold()).opacity(0.72)
                        if let a=s.account {
                            Text("MT5 • " + String(a.login)).font(.title2.bold()).monospacedDigit()
                            Text(a.isDemo ? "حساب Demo" : "حساب Real").font(.caption).opacity(0.84)
                        } else {
                            Text("MT5 غير متصل").font(.title2.bold())
                        }
                    }
                    Spacer()
                    BrandMark(size: 68, running: s.engine.running)
                }

                HStack(spacing: 12) {
                    heroStatus(marketOpen(s) ? "السوق مفتوح" : "السوق مغلق", marketOpen(s))
                    heroStatus(s.engine.running ? "المحرك مفعل" : "المحرك معطل", s.engine.running)
                    Spacer()
                    Text("\(s.settings.symbols.count) أزواج")
                        .font(.caption.weight(.semibold))
                        .opacity(0.82)
                }
            }
        }
    }

    private func sessionGoal(_ s: ServerSnapshot) -> some View {
        let limit = s.settings.sessionProfitLimit
        let realized = s.engine.sessionProfit ?? 0
        let hit = s.engine.sessionProfitHit ?? false
        let remaining = max(0, limit - realized)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Image(systemName: hit ? "checkmark.circle.fill" : "target")
                    .foregroundStyle(hit ? T4Palette.positive : T4Palette.accent)
                Text(hit ? "تم تحقيق هدف الجلسة" : "هدف الجلسة \(money(limit, s.account?.currency ?? "USD"))")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !hit, (s.engine.sessionStartBalance ?? 0) > 0 {
                    Text("\(money(realized, s.account?.currency ?? "USD")) / \(money(limit, s.account?.currency ?? "USD"))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if !hit {
                if (s.engine.sessionStartBalance ?? 0) > 0 {
                    Text("المتبقي \(money(remaining, s.account?.currency ?? "USD")) • يعتمد على الرصيد المحقق فقط")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("يبدأ احتساب الهدف عند تشغيل المحرك.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth:.infinity, alignment:.leading)
        .padding(.horizontal, 4)
    }

    private func engine(_ s: ServerSnapshot) -> some View {
        SurfaceCard {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("المحرك").font(.headline)
                        Text(s.settings.symbols.isEmpty ? "لا توجد أزواج نشطة" : s.settings.symbols.joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    StatusPill(title: s.engine.running ? "مفعل" : "معطل", isPositive: s.engine.running)
                }

                Button {
                    if s.engine.running {
                        showStopConfirmation=true
                    } else {
                        Task { await appModel.startEngine() }
                    }
                } label: {
                    Label(
                        s.engine.running ? "إيقاف المحرك" : "تشغيل المحرك",
                        systemImage: s.engine.running ? "stop.fill" : "play.fill"
                    )
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(s.engine.running ? T4Palette.negative : T4Palette.accent)
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
                        Text(x.state == "signal" ? (x.side == "BUY" ? "شراء" : "بيع") : "انتظار")
                            .font(.caption.bold())
                            .foregroundStyle(x.state == "signal" ? T4Palette.positive : .secondary)
                    }
                }
            }
        }
    }

    private func heroStatus(_ title:String,_ on:Bool)->some View {
        HStack(spacing:5) {
            Circle()
                .fill(on ? Color.white : Color.white.opacity(0.48))
                .frame(width:7,height:7)
            Text(title).font(.caption2.weight(.semibold))
        }
    }

    private func marketOpen(_ s:ServerSnapshot)->Bool {
        guard s.readiness.connected else { return false }
        let c=Calendar(identifier:.gregorian), now=Date()
        let w=c.component(.weekday,from:now)
        if w == 1 || w == 7 { return false }
        let h=c.component(.hour,from:now), m=c.component(.minute,from:now)
        return !((h == 23 && m >= 45) || (h == 0 && m < 30))
    }

    private func money(_ value:Double,_ currency:String)->String {
        value.formatted(.currency(code:currency.isEmpty ? "USD":currency))
    }
}

private struct StopEngineSheet:View {
    let confirm:()->Void
    @Environment(\.dismiss) private var dismiss

    var body:some View {
        VStack(spacing:18) {
            Capsule().fill(.secondary.opacity(0.20)).frame(width:38,height:5)
            Image(systemName:"stop.circle.fill")
                .font(.system(size:42))
                .foregroundStyle(T4Palette.negative)
            VStack(spacing:5) {
                Text("إيقاف المحرك؟").font(.title3.bold())
                Text("سيتم إيقاف التداول وإغلاق المراكز المتتبعة.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack {
                Button("إلغاء"){dismiss()}
                    .buttonStyle(.bordered)
                    .frame(maxWidth:.infinity)
                Button("إيقاف",role:.destructive){confirm()}
                    .buttonStyle(.borderedProminent)
                    .tint(T4Palette.negative)
                    .frame(maxWidth:.infinity)
            }
        }
        .padding(22)
    }
}
