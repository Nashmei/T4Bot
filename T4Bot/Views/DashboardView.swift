import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel

    private var snapshot: ServerSnapshot? { appModel.snapshot }
    private var engine: EngineSnapshot? { snapshot?.engine }

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    engineConsole
                    metrics
                    guardPanel
                    recentMarket
                }
                .padding(T4Style.contentInset)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("T4Bot")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await appModel.refreshSnapshot() }
        .loadingOverlay(appModel.isPerformingCommand)
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandMark(size: 50, running: engine?.running ?? false)
            VStack(alignment: .leading, spacing: 4) {
                Text("غرفة التحكم").font(.title3.bold())
                StatusDot(
                    text: engine?.running == true ? "المحرك يعمل" : "المحرك متوقف",
                    color: engine?.running == true ? T4Palette.positive : .secondary
                )
            }
            Spacer()
            StatusDot(
                text: snapshot?.account?.isDemo == true ? "Demo" : "Real",
                color: snapshot?.account?.isDemo == true ? T4Palette.cyan : T4Palette.warning
            )
        }
    }

    private var engineConsole: some View {
        Panel {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Engine").font(.headline)
                        Text(engine?.currentRegime ?? "بانتظار قراءة السوق")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(engine?.lastDecision ?? "—")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            if engine?.running == true { await appModel.stopEngine() }
                            else { await appModel.startEngine() }
                        }
                    } label: {
                        Label(engine?.running == true ? "إيقاف" : "تشغيل",
                              systemImage: engine?.running == true ? "stop.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(engine?.running == true ? T4Palette.negative : T4Palette.positive)

                    Button {
                        Task { await appModel.runAnalysis() }
                    } label: {
                        Label("تحليل الآن", systemImage: "scope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            MetricTile(title: "الرصيد", value: money(snapshot?.account?.balance), subtitle: snapshot?.account?.currency, icon: "banknote.fill")
            MetricTile(title: "Equity", value: money(snapshot?.account?.equity), subtitle: "حي", icon: "chart.bar.fill", tint: T4Palette.cyan)
            MetricTile(title: "عمليات المسح", value: "\(engine?.scanCount ?? 0)", subtitle: cycleText, icon: "dot.radiowaves.left.and.right")
            MetricTile(title: "المراكز", value: "\(engine?.trackedPositions ?? 0)/\(engine?.maxPositions ?? 0)", subtitle: engine?.selectedStrategy, icon: "rectangle.stack.fill", tint: T4Palette.warning)
        }
    }

    private var guardPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("حماية الحساب", subtitle: "Account Guard")
                if let guardState = snapshot?.accountGuard {
                    StatusDot(text: guardState.blocked ? "التداول محظور" : "الحماية سليمة",
                              color: guardState.blocked ? T4Palette.negative : T4Palette.positive)
                    if let reason = guardState.reason, !reason.isEmpty {
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("التراجع").foregroundStyle(.secondary)
                        Spacer()
                        Text(guardState.drawdownPct.map { String(format: "%.2f%%", $0) } ?? "—")
                            .monospacedDigit()
                    }.font(.subheadline)
                } else {
                    Text("الخادم لم يرسل حالة Account Guard بعد.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recentMarket: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("قراءة السوق", subtitle: "آخر قرارات Regime → Strategy")
                ForEach(Array((snapshot?.analysis ?? []).prefix(4))) { item in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.symbol).font(.headline.monospaced())
                            Text("\(item.regime) • \(item.state)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let strategy = item.strategy {
                                Text(strategy).font(.caption2).foregroundStyle(T4Palette.accent)
                            }
                        }
                        Spacer()
                        if let side = item.side, side != "NONE" {
                            Text(side)
                                .font(.caption.bold())
                                .foregroundStyle(side == "BUY" ? T4Palette.positive : T4Palette.negative)
                        }
                    }
                    if item.id != (snapshot?.analysis ?? []).prefix(4).last?.id { Divider() }
                }
            }
        }
    }

    private var cycleText: String {
        guard let s = engine?.lastCycleSeconds else { return "—" }
        return String(format: "%.3fs", s)
    }

    private func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}
