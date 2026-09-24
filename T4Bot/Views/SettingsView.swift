import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var draft = TradingSettings.defaults
    @State private var symbolsText = "EURUSD"
    @State private var loadedAccount: Int64?

    var body: some View {
        NavigationStack {
            Form {
                Section("الأزواج") {
                    TextField("EURUSD GBPUSD XAUUSD", text: $symbolsText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Text("افصل الرموز بمسافة. الخادم يتحقق من وجودها في MT5.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("المخاطرة") {
                    numericRow("المخاطرة %", value: $draft.riskPct)
                    numericRow("R:R", value: $draft.rr)
                    numericRow("الثقة %", value: $draft.minConfidence)
                    numericRow("الحماية %", value: $draft.protectionPct)
                    numericRow("مدة الصفقة بالدقائق", value: $draft.maxTradeMinutes)

                    Stepper("حد المراكز: \(draft.maxPositions)", value: $draft.maxPositions, in: 1...10)
                    Stepper("حد الخسائر: \(draft.maxConsecutiveLosses)", value: $draft.maxConsecutiveLosses, in: 0...20)
                    numericRow("حد Equity اليومي %", value: $draft.dailyLossLimitPct)
                }

                Section {
                    Button {
                        Task {
                            await appModel.update(settings: draft)
                            let symbols = normalizedSymbols
                            if !symbols.isEmpty {
                                await appModel.update(symbols: symbols)
                            }
                        }
                    } label: {
                        Label("حفظ على Mtbot", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appModel.isPerformingCommand || normalizedSymbols.isEmpty)
                }

                Section {
                    Text("القيم النهائية يحقق منها Mtbot مرة أخرى. التطبيق لا يغيّر استراتيجية التداول أو منطق إدارة المخاطر.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("الإعدادات")
            .onAppear(perform: loadSnapshot)
            .onChange(of: appModel.snapshot) { _, _ in
                loadSnapshot()
            }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }

    private var normalizedSymbols: [String] {
        symbolsText
            .uppercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
            .reduce(into: [String]()) { result, symbol in
                if !result.contains(symbol) {
                    result.append(symbol)
                }
            }
    }

    private func loadSnapshot() {
        guard let snapshot = appModel.snapshot else { return }
        let account = snapshot.account?.login
        guard loadedAccount != account || draft == TradingSettings.defaults else { return }

        draft = snapshot.settings
        symbolsText = snapshot.settings.symbols.joined(separator: " ")
        loadedAccount = account
    }

    @ViewBuilder
    private func numericRow(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 110)
        }
    }
}
