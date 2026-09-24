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

                    Stepper("حد المراكز: \(draft.maxPositions)", value: $draft.maxPositions, in: 1...10)
                    Stepper("حد الخسائر: \(draft.maxConsecutiveLosses)", value: $draft.maxConsecutiveLosses, in: 0...20)
                    numericRow("حد Equity اليومي %", value: $draft.dailyLossLimitPct)
                }

                Section("الإشعارات") {
                    Toggle("الجزيرة التفاعلية / Live Activity", isOn: $notificationManager.inAppEnabled)
                    Toggle("إشعارات خارج التطبيق", isOn: $notificationManager.outsideEnabled)

                    Toggle("فتح صفقة", isOn: $notificationManager.tradeOpened)
                    Toggle("إغلاق ونتيجة الصفقة", isOn: $notificationManager.tradeClosed)
                    Toggle("حماية الربح", isOn: $notificationManager.profitProtection)
                    Toggle("تنبيهات المحرك", isOn: $notificationManager.engineAlerts)
                    Toggle("اتصال MT5", isOn: $notificationManager.connectionAlerts)

                    LabeledContent("Live Activities") {
                        Label(
                            notificationManager.liveActivitiesEnabled ? "متاحة" : "غير متاحة",
                            systemImage: notificationManager.liveActivitiesEnabled ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(notificationManager.liveActivitiesEnabled ? .green : .red)
                    }

                    LabeledContent("Push") {
                        Text(notificationManager.pushStatusText)
                            .font(.caption)
                            .foregroundStyle(notificationManager.deviceToken == nil ? .secondary : .green)
                    }

                    if let status = appModel.notificationStatus {
                        LabeledContent("خادم APNs") {
                            Text(status.configured ? "جاهز" : "غير مهيأ")
                                .foregroundStyle(status.configured ? .green : .orange)
                        }
                        LabeledContent("الأجهزة المسجلة", value: "\(status.registeredDevices)")
                    }

                    Button {
                        Task {
                            await notificationManager.requestAuthorization()
                            await appModel.refreshNotificationStatus()
                        }
                    } label: {
                        Label("تفعيل صلاحية الإشعارات", systemImage: "bell.badge.fill")
                    }

                    Button {
                        Task {
                            appModel.operationMessage = await notificationManager.testLiveActivity(
                                account: appModel.snapshot?.account
                            )
                        }
                    } label: {
                        Label("اختبار الجزيرة التفاعلية", systemImage: "waveform.path.ecg")
                    }

                    Button {
                        Task {
                            appModel.operationMessage = await notificationManager.testLocalNotification()
                        }
                    } label: {
                        Label("اختبار إشعار iOS", systemImage: "bell.and.waves.left.and.right.fill")
                    }

                    Button {
                        Task { await appModel.testServerPush() }
                    } label: {
                        Label("اختبار Push من Mtbot", systemImage: "paperplane.fill")
                    }

                    Text("اختبار الجزيرة يعمل محلياً على الجهاز. أما Push خارج التطبيق فيحتاج أن يكون التطبيق موقّعاً بصلاحية APNs وأن يكون مزود APNs مضبوطاً على خادم Mtbot.")
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
                    Text("T4Bot يعرض جميع الرموز التي يرجعها MT5 مباشرة، بما فيها رموز البروكر ذات اللاحقات.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("الإعدادات")
            .onAppear {
                loadSnapshot(force: true)
                Task {
                    await appModel.loadSymbols()
                    await appModel.refreshNotificationStatus()
                }
            }
            .onChange(of: appModel.snapshot) { _, _ in
                loadSnapshot(force: false)
            }
            .onChange(of: draft) { _, _ in
                hasLocalEdits = true
            }
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
        let source = query.isEmpty
            ? available
            : available.filter { $0.localizedCaseInsensitiveContains(query) }

        return source.sorted { lhs, rhs in
            let leftSelected = selection.contains(lhs)
            let rightSelected = selection.contains(rhs)
            if leftSelected != rightSelected {
                return leftSelected && !rightSelected
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
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
                        Text("\(selection.count) مختار")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("إلغاء الكل", role: .destructive) {
                            selection.removeAll()
                        }
                    }
                }

                Section("رموز MT5") {
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
