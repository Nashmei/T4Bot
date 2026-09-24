import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var notificationManager: NotificationManager

    @State private var draft = TradingSettings.defaults
    @State private var selectedSymbols: Set<String> = []
    @State private var loadedAccount: Int64?
    @State private var hasLocalEdits = false
    @State private var showSymbolPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("الأزواج") {
                    Button {
                        showSymbolPicker = true
                        Task { await appModel.loadSymbols() }
                    } label: {
                        HStack {
                            Label("اختيار الأزواج من MT5", systemImage: "list.bullet.rectangle")
                            Spacer()
                            Text("(selectedSymbols.count)")
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
                                        .background(.blue.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                }

                Section("المخاطرة") {
                    numericRow("المخاطرة %", value: $draft.riskPct)
                    numericRow("R:R", value: $draft.rr)
                    numericRow("الثقة %", value: $draft.minConfidence)
                    numericRow("الحماية %", value: $draft.protectionPct)
                    numericRow("مدة الصفقة بالدقائق", value: $draft.maxTradeMinutes)

                    Stepper("حد المراكز: (draft.maxPositions)", value: $draft.maxPositions, in: 1...10)
                    Stepper("حد الخسائر: (draft.maxConsecutiveLosses)", value: $draft.maxConsecutiveLosses, in: 0...20)
                    numericRow("حد Equity اليومي %", value: $draft.dailyLossLimitPct)
                }

                Section("الإشعارات") {
                    Toggle("الجزيرة التفاعلية داخل التطبيق", isOn: $notificationManager.inAppEnabled)
                    Toggle("إشعارات خارج التطبيق", isOn: $notificationManager.outsideEnabled)
                    Toggle("فتح صفقة", isOn: $notificationManager.tradeOpened)
                    Toggle("إغلاق ونتيجة الصفقة", isOn: $notificationManager.tradeClosed)
                    Toggle("حماية الربح", isOn: $notificationManager.profitProtection)
                    Toggle("تنبيهات المحرك", isOn: $notificationManager.engineAlerts)
                    Toggle("اتصال MT5", isOn: $notificationManager.connectionAlerts)

                    Button {
                        Task { await notificationManager.requestAuthorization() }
                    } label: {
                        Label("تفعيل صلاحية الإشعارات", systemImage: "bell.badge.fill")
                    }

                    Text("الجزيرة التفاعلية تستخدم Live Activity. إشعارات الخارج تُرسل عبر APNs عند تفعيل مفاتيح المزود على خادم Mtbot.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task {
                            draft.symbols = selectedSymbols.sorted()
                            await appModel.update(settings: draft)
                            await appModel.update(symbols: draft.symbols)
                            hasLocalEdits = false
                        }
                    } label: {
                        Label("حفظ على Mtbot", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appModel.isPerformingCommand || selectedSymbols.isEmpty)
                }

                Section {
                    Text("T4Bot يعرض الرموز الفعلية التي يوفرها MT5 على الخادم. لا توجد قائمة أزواج ثابتة داخل التطبيق.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("الإعدادات")
            .onAppear {
                loadSnapshot(force: true)
                Task { await appModel.loadSymbols() }
            }
            .onChange(of: appModel.snapshot) { _, _ in
                loadSnapshot(force: false)
            }
            .onChange(of: draft) { _, _ in hasLocalEdits = true }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPickerView(
                    available: appModel.availableSymbols,
                    selection: $selectedSymbols
                )
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
    private func numericRow(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 110)
        }
    }
}

private struct SymbolPickerView: View {
    let available: [String]
    @Binding var selection: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        guard !query.isEmpty else { return available }
        return available.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button("تحديد الكل") {
                            selection = Set(available)
                        }
                        Spacer()
                        Button("إلغاء الكل", role: .destructive) {
                            selection.removeAll()
                        }
                    }
                }

                ForEach(filtered, id: \.self) { symbol in
                    Button {
                        if selection.contains(symbol) {
                            selection.remove(symbol)
                        } else {
                            selection.insert(symbol)
                        }
                    } label: {
                        HStack {
                            Text(symbol)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selection.contains(symbol) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "ابحث في رموز MT5")
            .navigationTitle("أزواج MT5")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
            }
        }
    }
}
