import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            List {
                if let snapshot = appModel.snapshot {
                    Section {
                        Button {
                            Task { await appModel.runAnalysis() }
                        } label: {
                            Label("تحليل الأزواج المختارة الآن", systemImage: "waveform.path.ecg")
                        }
                        .disabled(appModel.isPerformingCommand)
                    }

                    if snapshot.analysis.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "لا يوجد تحليل محفوظ",
                                systemImage: "chart.xyaxis.line",
                                description: Text("شغّل التحليل للحصول على قراءة منظمة من نفس Analyzer في Mtbot.")
                            )
                        }
                    } else {
                        Section("النتائج") {
                            ForEach(snapshot.analysis) { item in
                                AnalysisRow(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("التحليل")
            .refreshable {
                await appModel.refresh()
            }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }
}

private struct AnalysisRow: View {
    let item: AnalysisSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.symbol)
                    .font(.headline)
                Spacer()
                Text(arabic(item.regime))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if item.state == "signal" {
                HStack {
                    Label(item.side ?? "—", systemImage: item.side == "BUY" ? "arrow.up.right" : "arrow.down.right")
                    Spacer()
                    if let confidence = item.confidence {
                        Text("\(confidence.formatted(.number.precision(.fractionLength(0))))%")
                            .monospacedDigit()
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(item.side == "BUY" ? .green : .red)

                if let strategy = item.strategy {
                    Text(arabic(strategy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label(arabic(item.reason ?? "لا توجد فرصة حالياً"), systemImage: "pause.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func arabic(_ raw: String) -> String {
        let map = [
            "TREND": "اتجاه", "NO_TRADE": "انتظار", "RANGE": "تذبذب",
            "trend_wait_pullback": "انتظار تصحيح مناسب",
            "waiting_live_momentum": "انتظار زخم مؤكد",
            "gold_wait_confirmation": "الذهب: انتظار تأكيد",
            "spread_spike": "السبريد مرتفع",
            "insufficient_ticks": "بيانات السوق غير مكتملة"
        ]
        return map[raw] ?? raw.replacingOccurrences(of: "_", with: " ")
    }
}
