import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showStopConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    if let snapshot = appModel.snapshot {
                        VStack(spacing: 16) {
                            hero(snapshot)

                            if let account = snapshot.account {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    MetricCard(
                                        title: "الرصيد",
                                        value: money(account.balance, currency: account.currency),
                                        systemImage: "banknote.fill"
                                    )
                                    MetricCard(
                                        title: "Equity",
                                        value: money(account.equity, currency: account.currency),
                                        systemImage: "chart.line.uptrend.xyaxis",
                                        tint: .purple
                                    )
                                    MetricCard(
                                        title: "العائم",
                                        value: money(account.profit, currency: account.currency),
                                        systemImage: "waveform.path.ecg",
                                        tint: account.profit >= 0 ? .green : .red
                                    )
                                    MetricCard(
                                        title: "المراكز",
                                        value: "\(snapshot.positions.count) / \(snapshot.engine.maxPositions)",
                                        systemImage: "square.stack.3d.up.fill",
                                        tint: .orange
                                    )
                                }
                            }

                            engineCard(snapshot)

                            if !snapshot.analysis.isEmpty {
                                analysisPreview(snapshot.analysis)
                            }

                            readinessCard(snapshot.readiness)
                        }
                        .padding(16)
                    } else {
                        ContentUnavailableView {
                            Label("بانتظار الاتصال", systemImage: "antenna.radiowaves.left.and.right")
                        } description: {
                            Text("تظهر البيانات فور وصول أول تحديث.")
                        } actions: {
                            Button("تحديث") { Task { await appModel.refresh() } }
                        }
                    }
                }
            }
            .navigationTitle("T4Bot")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    connectionPill
                }
            }
            .refreshable { await appModel.refresh() }
            .loadingOverlay(appModel.isPerformingCommand)
            .confirmationDialog(
                "إيقاف المحرك؟",
                isPresented: $showStopConfirmation,
                titleVisibility: .visible
            ) {
                Button("إيقاف وإغلاق المراكز المتتبعة", role: .destructive) {
                    Task { await appModel.stopEngine() }
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("عند الإيقاف سيحاول Mtbot إغلاق المراكز التي يديرها.")
            }
        }
    }

    private func hero(_ snapshot: ServerSnapshot) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.engine.running ? "المحرك يعمل" : "المحرك متوقف")
                            .font(.title2.bold())
                        Text(snapshot.account.map { "حساب MT5 • \($0.login)" } ?? "MT5 غير متصل")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill((snapshot.engine.running ? Color.green : Color.secondary).opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: snapshot.engine.running ? "bolt.fill" : "pause.fill")
                            .foregroundStyle(snapshot.engine.running ? .green : .secondary)
                    }
                }

                HStack(spacing: 18) {
                    Label("\(snapshot.engine.scanCount)", systemImage: "arrow.triangle.2.circlepath")
                    Label(String(format: "%.2f ث", snapshot.engine.lastCycleSeconds), systemImage: "timer")
                    if let account = snapshot.account {
                        Label(account.isDemo ? "DEMO" : "LIVE", systemImage: "shield.fill")
                            .foregroundStyle(account.isDemo ? .blue : .orange)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func engineCard(_ snapshot: ServerSnapshot) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    "المحرك",
                    subtitle: snapshot.settings.symbols.isEmpty
                        ? "لم يتم اختيار أسواق"
                        : snapshot.settings.symbols.joined(separator: " • ")
                )

                Button {
                    if snapshot.engine.running {
                        showStopConfirmation = true
                    } else {
                        Task { await appModel.startEngine() }
                    }
                } label: {
                    Label(
                        snapshot.engine.running ? "إيقاف المحرك" : "تشغيل المحرك",
                        systemImage: snapshot.engine.running ? "stop.fill" : "play.fill"
                    )
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(snapshot.engine.running ? .red : T4Palette.accent)
            }
        }
    }

    private func analysisPreview(_ rows: [AnalysisSnapshot]) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("آخر قراءة AI", subtitle: "تتحدث مباشرة من المحرك")

                ForEach(rows.prefix(5)) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.primary.opacity(0.055))
                                .frame(width: 40, height: 40)
                            Text(String(item.symbol.prefix(3)))
                                .font(.caption.bold())
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.symbol)
                                .font(.subheadline.weight(.bold))
                            Text(displayText(item.strategy ?? item.reason ?? item.state))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if let confidence = item.confidence {
                            Text("\(Int(confidence))%")
                                .font(.caption.monospacedDigit().weight(.bold))
                        } else {
                            Text(displayText(item.regime))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func readinessCard(_ readiness: ReadinessSnapshot) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("الجاهزية", subtitle: readiness.ready ? "كل الأنظمة جاهزة" : "يوجد عنصر يحتاج انتباه")
                HStack(spacing: 8) {
                    readinessBadge("MT5", readiness.connected)
                    readinessBadge("Trading", readiness.tradeAllowed && readiness.accountTradeAllowed)
                    readinessBadge("Expert", readiness.tradeExpert)
                }
            }
        }
    }

    private func readinessBadge(_ title: String, _ ready: Bool) -> some View {
        Label(title, systemImage: ready ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ready ? .green : .red)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.primary.opacity(0.045), in: Capsule())
    }

    private var connectionPill: some View {
        let state = appModel.connectionState
        return HStack(spacing: 6) {
            Circle()
                .fill(state == .live ? Color.green : state == .reconnecting ? Color.orange : Color.red)
                .frame(width: 7, height: 7)
            Text(state == .live ? "مباشر" : state == .reconnecting ? "يتصل" : "غير متصل")
                .font(.caption2.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }

    private func displayText(_ raw: String) -> String {
        let map = [
            "TREND": "اتجاه",
            "RANGE": "تذبذب",
            "BREAKOUT": "اختراق",
            "VOLATILE": "تذبذب قوي",
            "MIXED": "مختلط",
            "NO_TRADE": "انتظار",
            "trend_wait_pullback": "انتظار تصحيح",
            "waiting_live_momentum": "انتظار زخم",
            "gold_wait_confirmation": "انتظار تأكيد الذهب",
            "spread_spike": "السبريد مرتفع",
            "insufficient_ticks": "بيانات السوق غير مكتملة"
        ]
        return map[raw] ?? raw.replacingOccurrences(of: "_", with: " ")
    }

    private func money(_ value: Double, currency: String) -> String {
        value.formatted(.currency(code: currency.isEmpty ? "USD" : currency))
    }
}
