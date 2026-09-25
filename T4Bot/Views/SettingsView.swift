import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var notificationManager: NotificationManager

    @State private var draft = TradingSettings.defaults
    @State private var selectedSymbols: Set<String> = []
    @State private var loadedAccount: Int64?
    @State private var hasLocalEdits = false
    @State private var showSymbolPicker = false
    @FocusState private var numericFieldFocused: Bool
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("المظهر", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("المظهر")
                } footer: {
                    Text("تلقائي يتبع إعداد الآيفون.")
                }

                Section {
                    Button {
                        showSymbolPicker = true
                        Task { await appModel.loadSymbols() }
                    } label: {
                        HStack {
                            Label("اختيار الأسواق", systemImage: "chart.bar.xaxis")
                            Spacer()
                            Text("\(selectedSymbols.count)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !selectedSymbols.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedSymbols.sorted(), id: \.self) { symbol in
                                    Text(symbol)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(T4Palette.accent.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                } header: {
                    Text("الأسواق")
                } footer: {
                    Text("الأكثر تداولاً تظهر أولاً، والبحث يشمل بقية رموز MT5 المتاحة.")
                }

                Section("المخاطرة") {
                    numericRow("المخاطرة %", value: $draft.riskPct, help: "النسبة المستخدمة لحجم الصفقة.")
                    numericRow("الثقة %", value: $draft.minConfidence, help: "أقل ثقة مطلوبة قبل السماح بالدخول.")
                    Stepper("حد المراكز: \(draft.maxPositions)", value: $draft.maxPositions, in: 1...10)
                    Stepper("حد الخسائر: \(draft.maxConsecutiveLosses)", value: $draft.maxConsecutiveLosses, in: 0...20)
                    numericRow("حد Equity اليومي %", value: $draft.dailyLossLimitPct, help: "يوقف الدخول عند بلوغ الحد.")
                }

                Section {
                    numericRow("R:R", value: $draft.rr, help: "0 = يحدده AI لكل صفقة.")
                    numericRow("SL Points", value: $draft.slPoints, help: "0 = AI.")
                    numericRow("TP Points", value: $draft.tpPoints, help: "0 = AI.")
                    numericRow("الحماية %", value: $draft.protectionPct, help: "0 = AI.")
                    numericRow("Trailing Gap %", value: $draft.trailingGapPct, help: "0 = AI.")
                    numericRow("المدة بالدقائق", value: $draft.maxTradeMinutes, help: "0 = AI.")

                    Button {
                        draft.rr = 0
                        draft.slPoints = 0
                        draft.tpPoints = 0
                        draft.protectionPct = 0
                        draft.trailingGapPct = 0
                        draft.maxTradeMinutes = 0
                    } label: {
                        Label("إرجاع إدارة الصفقة إلى AI", systemImage: "brain.head.profile")
                    }
                } header: {
                    Text("إدارة AI")
                } footer: {
                    Text("القيمة 0 تعني أن AI يقرر الإعداد حسب كل فرصة. أي قيمة موجبة تصبح Override يدوي.")
                }

                Section("الإشعارات") {
                    Toggle("Live Activity", isOn: $notificationManager.inAppEnabled)
                    Toggle("إشعار iOS محلي", isOn: $notificationManager.outsideEnabled)
                    Toggle("فتح صفقة", isOn: $notificationManager.tradeOpened)
                    Toggle("إغلاق الصفقة", isOn: $notificationManager.tradeClosed)
                    Toggle("حماية الربح", isOn: $notificationManager.profitProtection)

                    Button {
                        Task { await notificationManager.requestAuthorization() }
                    } label: {
                        Label("تفعيل صلاحية الإشعارات", systemImage: "bell.badge.fill")
                    }
                }

                Section {
                    Button {
                        numericFieldFocused = false
                        Task {
                            draft.symbols = selectedSymbols.sorted()
                            await appModel.update(settings: draft)
                            await appModel.update(symbols: draft.symbols)
                            hasLocalEdits = false
                        }
                    } label: {
                        Label("حفظ الإعدادات", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appModel.isPerformingCommand || selectedSymbols.isEmpty)
                }
            }
            .t4ListBackground()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("الإعدادات")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") { numericFieldFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadSnapshot(force: true)
                Task {
                    await appModel.loadSymbols()
                    await notificationManager.refreshAuthorizationStatus()
                }
            }
            .onChange(of: appModel.snapshot) { _, _ in loadSnapshot(force: false) }
            .onChange(of: draft) { _, _ in hasLocalEdits = true }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPickerView(available: appModel.availableSymbols, selection: $selectedSymbols)
            }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }

    private func loadSnapshot(force: Bool) {
        guard let snapshot = appModel.snapshot else { return }
        let account = snapshot.account?.login
        guard force || loadedAccount != account || !hasLocalEdits else { return }

        draft = snapshot.settings
        selectedSymbols = Set(snapshot.settings.symbols)
        loadedAccount = account
        hasLocalEdits = false
    }

    @ViewBuilder
    private func numericRow(_ title: String, value: Binding<Double>, help: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($numericFieldFocused)
                    .frame(maxWidth: 110)
            }

            Text(help)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SymbolPickerView: View {
    private let popularBases = [
        "XAUUSD", "EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD",
        "USDCHF", "NZDUSD", "EURJPY", "GBPJPY", "EURGBP", "XAGUSD"
    ]

    let available: [String]
    @Binding var selection: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var searched: [String] {
        query.isEmpty ? available : available.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var popular: [String] {
        searched
            .filter { popularity($0) < 999 }
            .sorted {
                let lhs = popularity($0), rhs = popularity($1)
                if lhs != rhs { return lhs < rhs }
                return $0.localizedStandardCompare($1) == .orderedAscending
            }
    }

    private var other: [String] {
        searched
            .filter { popularity($0) == 999 }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func popularity(_ symbol: String) -> Int {
        let upper = symbol.uppercased()
        return popularBases.firstIndex(where: { upper.contains($0) }) ?? 999
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button("تحديد الظاهر") {
                            selection.formUnion(searched)
                        }
                        Spacer()
                        Text("\(selection.count) مختار")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("إلغاء الكل", role: .destructive) {
                            selection.removeAll()
                        }
                    }
                }

                if !popular.isEmpty {
                    Section("الأكثر تداولاً") {
                        ForEach(popular, id: \.self) { symbol in
                            symbolRow(symbol)
                        }
                    }
                }

                if !other.isEmpty {
                    Section("بقية الأسواق") {
                        ForEach(other, id: \.self) { symbol in
                            symbolRow(symbol)
                        }
                    }
                }
            }
            .t4ListBackground()
            .searchable(text: $query, prompt: "ابحث في رموز MT5")
            .navigationTitle("الأسواق")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
            }
        }
    }

    private func symbolRow(_ symbol: String) -> some View {
        Button {
            if selection.contains(symbol) {
                selection.remove(symbol)
            } else {
                selection.insert(symbol)
            }
        } label: {
            HStack {
                Text(symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: selection.contains(symbol) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection.contains(symbol) ? T4Palette.accent : .secondary)
            }
        }
    }
}
