import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var connectionStore: ConnectionStore
    @State private var showLogin = false
    @State private var showDisconnect = false

    var body: some View {
        NavigationStack {
            List {
                if let account = appModel.snapshot?.account {
                    Section("MT5") {
                        LabeledContent("الحساب", value: String(account.login))
                        LabeledContent("الخادم", value: account.server)
                        LabeledContent("الوضع", value: account.isDemo ? "DEMO" : "غير تجريبي")
                        LabeledContent("العملة", value: account.currency)
                    }

                    Section("الحساب") {
                        LabeledContent("Balance", value: account.balance.formatted(.currency(code: account.currency)))
                        LabeledContent("Equity", value: account.equity.formatted(.currency(code: account.currency)))
                        LabeledContent("Margin", value: account.margin.formatted(.currency(code: account.currency)))
                        LabeledContent("Free Margin", value: account.marginFree.formatted(.currency(code: account.currency)))
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "MT5 غير متصل",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("اربط حساب DEMO من الخادم.")
                        )
                    }
                }

                if let readiness = appModel.snapshot?.readiness {
                    Section("الجاهزية") {
                        readinessRow("MT5 متصل", readiness.connected)
                        readinessRow("Terminal Trading", readiness.tradeAllowed)
                        readinessRow("Account Trading", readiness.accountTradeAllowed)
                        readinessRow("Expert Trading", readiness.tradeExpert)
                    }
                }

                Section {
                    Button {
                        showLogin = true
                    } label: {
                        Label("ربط حساب MT5 DEMO", systemImage: "person.badge.key")
                    }
                    .disabled(appModel.snapshot?.engine.running == true)
                }

                Section("اتصال T4Bot") {
                    Text(connectionStore.baseURLString)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)

                    Button("نسيان اتصال التطبيق", role: .destructive) {
                        showDisconnect = true
                    }
                }
            }
            .navigationTitle("الحساب")
            .sheet(isPresented: $showLogin) {
                MT5LoginView()
            }
            .confirmationDialog(
                "نسيان اتصال T4Bot؟",
                isPresented: $showDisconnect,
                titleVisibility: .visible
            ) {
                Button("نسيان الخادم والرمز", role: .destructive) {
                    appModel.disconnect()
                    connectionStore.clear()
                }
                Button("إلغاء", role: .cancel) {}
            }
        }
    }

    private func readinessRow(_ title: String, _ value: Bool) -> some View {
        HStack {
            Label(title, systemImage: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(value ? .primary : .secondary)
            Spacer()
            Text(value ? "جاهز" : "غير جاهز")
                .font(.caption)
                .foregroundStyle(value ? .green : .red)
        }
    }
}

private struct MT5LoginView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var server = "MetaQuotes-Demo"
    @State private var login = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server", text: $server)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Login", text: $login)
                        .keyboardType(.numberPad)

                    SecureField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("بيانات MT5")
                } footer: {
                    Text("T4Bot لا يحفظ كلمة مرور MT5. يتم إرسالها مباشرة إلى خادمك عبر HTTPS.")
                }

                Section {
                    Button {
                        guard let loginNumber = Int64(login), !server.isEmpty, !password.isEmpty else {
                            appModel.errorMessage = "تحقق من Server وLogin وPassword."
                            return
                        }

                        Task {
                            let success = await appModel.login(
                                server: server,
                                login: loginNumber,
                                password: password
                            )
                            password = ""
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        Label("تسجيل الدخول", systemImage: "lock.open.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appModel.isPerformingCommand)
                }
            }
            .navigationTitle("ربط MT5")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") {
                        password = ""
                        dismiss()
                    }
                }
            }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }
}
