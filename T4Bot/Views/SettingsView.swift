import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = TradingSettings.defaults
    @State private var loaded = false

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    riskPanel
                    limitsPanel
                    executionPanel
                }
                .padding(16)
            }
        }
        .navigationTitle("إعدادات التداول")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("حفظ") {
                    Task { await appModel.update(settings: draft); dismiss() }
                }
                .fontWeight(.semibold)
                .disabled(appModel.isPerformingCommand)
            }
        }
        .onAppear {
            guard !loaded else { return }
            if let settings = appModel.snapshot?.settings { draft = settings }
            loaded = true
        }
        .loadingOverlay(appModel.isPerformingCommand)
    }

    private var riskPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("المخاطرة", subtitle: "هذه إعدادات مستوى الحساب؛ الاستراتيجية تحدد Entry / SL / TP")
                Stepper(value: $draft.riskPct, in: 0.05...20, step: 0.05) {
                    row("المخاطرة لكل صفقة", String(format: "%.2f%%", draft.riskPct))
                }
                Stepper(value: $draft.dailyLossLimitPct, in: 0...30, step: 0.5) {
                    row("حد الخسارة اليومي", String(format: "%.1f%%", draft.dailyLossLimitPct))
                }
                Stepper(value: $draft.sessionProfitLimit, in: 0...100000, step: 10) {
                    row("هدف الجلسة", draft.sessionProfitLimit == 0 ? "معطل" : draft.sessionProfitLimit.formatted(.number.precision(.fractionLength(0...2))))
                }
            }
        }
    }

    private var limitsPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("الحدود والحماية")
                Stepper(value: $draft.maxPositions, in: 1...20) {
                    row("أقصى مراكز مفتوحة", "\(draft.maxPositions)")
                }
                Stepper(value: $draft.maxConsecutiveLosses, in: 0...20) {
                    row("الخسائر المتتالية", draft.maxConsecutiveLosses == 0 ? "معطل" : "\(draft.maxConsecutiveLosses)")
                }
            }
        }
    }

    private var executionPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("نوع الحساب")
                Toggle("السماح بالتداول الحقيقي", isOn: $draft.realTradingEnabled)
                    .tint(T4Palette.negative)
                Text("لا يغيّر هذا الزر حساب MT5 نفسه. يحدد فقط هل T4Bot يسمح بالتنفيذ عندما يكون الحساب Real.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}
