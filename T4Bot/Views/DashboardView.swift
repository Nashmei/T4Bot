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
            ScrollView {
                if let snapshot = appModel.snapshot {
                    VStack(spacing: 16) {
                        header(snapshot)

                        if let account = snapshot.account {
                            LazyVGrid(columns: columns, spacing: 12) {
                                MetricCard(
                                    title: "الرصيد",
                                    value: money(account.balance, currency: account.currency),
                                    systemImage: "banknote"
                                )
                                MetricCard(
                                    title: "Equity",
                                    value: money(account.equity, currency: account.currency),
                                    systemImage: "chart.line.uptrend.xyaxis"
                                )
                                MetricCard(
                                    title: "الربح العائم",
                                    value: money(account.profit, currency: account.currency),
                                    systemImage: "waveform.path.ecg"
                                )
                                MetricCard(
                                    title: "المراكز",
                                    value: "\(snapshot.positions.count) / \(snapshot.engine.maxPositions)",
                                    systemImage: "square.stack.3d.up"
                                )
                            }
                        }

                        engineCard(snapshot)
                        readinessCard(snapshot.readiness)

                        if !snapshot.analysis.isEmpty {
                            analysisPreview(snapshot.analysis)
                        }
                    }
                    .padding()
                } else {
                    ContentUnavailableView {
                        Label("بانتظار الخادم", systemImage: "server.rack")
                    } description: {
                        Text("سيظهر وضع Mtbot هنا بعد أول تحديث ناجح.")
                    } actions: {
                        Button("تحديث") {
                            Task { await appModel.refresh() }
                        }
                    }
                }
            }
            .navigationTitle("لوحة التحكم")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await appModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(appModel.isRefreshing)
                    .accessibilityLabel("تحديث")
                }
            }
            .refreshable {
                await appModel.refresh()
            }
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
                Text("سلوك Mtbot الحالي عند Stop يحاول إغلاق المراكز التي يديرها البوت. لن يرسل T4Bot الأمر بدون هذا التأكيد.")
            }
        }
    }

    private func header(_ snapshot: ServerSnapshot) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(
                        title: snapshot.engine.running ? "المحرك يعمل" : "المحرك متوقف",
                        isPositive: snapshot.engine.running
                    )
                    Spacer()
                    if let account = snapshot.account {
                        Text(account.isDemo ? "DEMO" : "غير تجريبي")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(account.isDemo ? .blue : .red)
                    }
                }

                if let account = snapshot.account {
                    Text("\(account.login) • \(account.server)")
                        .font(.headline)
                        .textSelection(.enabled)
                } else {
                    Text("MT5 غير متصل")
                        .font(.headline)
                }

                HStack(spacing: 16) {
                    Label("\(snapshot.engine.scanCount)", systemImage: "arrow.triangle.2.circlepath")
                    Label(String(format: "%.2f ث", snapshot.engine.lastCycleSeconds), systemImage: "timer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func engineCard(_ snapshot: ServerSnapshot) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("المحرك")
                    .font(.headline)

                Text(snapshot.settings.symbols.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(snapshot.engine.running ? .red : .accentColor)
            }
        }
    }

    private func readinessCard(_ readiness: ReadinessSnapshot) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("جاهزية MT5")
                    .font(.headline)

                readinessRow("الاتصال", readiness.connected)
                readinessRow("Terminal Trading", readiness.tradeAllowed)
                readinessRow("Account Trading", readiness.accountTradeAllowed)
                readinessRow("Expert Trading", readiness.tradeExpert)
            }
        }
    }

    private func analysisPreview(_ rows: [AnalysisSnapshot]) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("آخر تحليل")
                    .font(.headline)

                ForEach(rows.prefix(4)) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.symbol)
                                .font(.subheadline.weight(.semibold))
                            Text(item.strategy ?? item.reason ?? item.state)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.regime)
                            .font(.caption.weight(.medium))
                    }
                }
            }
        }
    }

    private func readinessRow(_ title: String, _ value: Bool) -> some View {
        HStack {
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(value ? .green : .red)
            Text(title)
            Spacer()
        }
        .font(.subheadline)
    }

    private func money(_ value: Double, currency: String) -> String {
        value.formatted(.currency(code: currency.isEmpty ? "USD" : currency))
    }
}
