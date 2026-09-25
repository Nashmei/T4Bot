import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    VStack(spacing: 14) {
                        SurfaceCard {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("تحليل AI")
                                        .font(.title3.bold())
                                    Text("يقرأ الأسواق المختارة ويعرض القرار باختصار.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    Task { await appModel.runAnalysis() }
                                } label: {
                                    Image(systemName: "sparkles")
                                        .font(.headline)
                                        .frame(width: 42, height: 42)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(T4Palette.accent)
                                .disabled(appModel.isPerformingCommand)
                            }
                        }

                        if let snapshot = appModel.snapshot {
                            if snapshot.analysis.isEmpty {
                                ContentUnavailableView(
                                    "لا يوجد تحليل محفوظ",
                                    systemImage: "chart.xyaxis.line",
                                    description: Text("اضغط زر التحليل للحصول على قراءة جديدة.")
                                )
                                .padding(.top, 50)
                            } else {
                                ForEach(snapshot.analysis) { item in
                                    AnalysisCard(item: item)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("التحليل")
            .refreshable { await appModel.refresh() }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }
}

private struct AnalysisCard: View {
    let item: AnalysisSnapshot

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.symbol)
                            .font(.title3.bold())
                        Text(arabic(item.regime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    stateBadge
                }

                Divider().opacity(0.5)

                if item.state == "signal" {
                    HStack {
                        Label(
                            item.side == "BUY" ? "شراء" : "بيع",
                            systemImage: item.side == "BUY" ? "arrow.up.right" : "arrow.down.right"
                        )
                        .font(.headline)
                        .foregroundStyle(item.side == "BUY" ? .green : .red)

                        Spacer()

                        if let confidence = item.confidence {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(confidence))%")
                                    .font(.headline.monospacedDigit())
                                Text("ثقة")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let strategy = item.strategy {
                        explanationRow("الاستراتيجية", arabic(strategy), "brain.head.profile")
                    }
                } else {
                    explanationRow(
                        "القرار",
                        arabic(item.reason ?? "لا توجد فرصة حالياً"),
                        "pause.circle.fill"
                    )
                }

                Text("آخر تحديث: \(Date(timeIntervalSince1970: item.updatedAt), style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var stateBadge: some View {
        let signal = item.state == "signal"
        return Text(signal ? "فرصة" : "انتظار")
            .font(.caption.bold())
            .foregroundStyle(signal ? Color.green : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((signal ? Color.green : Color.secondary).opacity(0.10), in: Capsule())
    }

    private func explanationRow(_ title: String, _ value: String, _ image: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: image)
                .foregroundStyle(T4Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
        }
    }

    private func arabic(_ raw: String) -> String {
        let map = [
            "TREND": "اتجاه واضح",
            "RANGE": "تذبذب جانبي",
            "BREAKOUT": "اختراق",
            "VOLATILE": "حركة قوية",
            "MIXED": "سوق مختلط",
            "UNKNOWN": "غير واضح",
            "NO_TRADE": "لا توجد صفقة مناسبة",
            "trend_wait_pullback": "انتظار تصحيح مناسب",
            "waiting_live_momentum": "انتظار زخم مؤكد",
            "gold_wait_confirmation": "الذهب: انتظار تأكيد",
            "spread_spike": "السبريد مرتفع",
            "insufficient_ticks": "بيانات السوق غير مكتملة",
            "stale_ticks": "السعر الحالي غير محدث"
        ]
        return map[raw] ?? raw.replacingOccurrences(of: "_", with: " ")
    }
}
