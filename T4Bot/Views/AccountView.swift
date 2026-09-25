import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var connectionStore: ConnectionStore
    @State private var showLogin = false
    @State private var showDisconnect = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    VStack(spacing: 16) {
                        if let account = appModel.snapshot?.account {
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("حساب MT5")
                                                .font(.title3.bold())
                                            Text(String(account.login))
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(account.isDemo ? "DEMO" : "LIVE")
                                            .font(.caption.bold())
                                            .foregroundStyle(account.isDemo ? .blue : .orange)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background((account.isDemo ? Color.blue : Color.orange).opacity(0.10), in: Capsule())
                                    }

                                    Divider().opacity(0.5)

                                    HStack {
                                        accountMetric("Balance", account.balance, account.currency)
                                        accountMetric("Equity", account.equity, account.currency)
                                    }

                                    HStack {
                                        accountMetric("Margin", account.margin, account.currency)
                                        accountMetric("Free", account.marginFree, account.currency)
                                    }
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "MT5 غير متصل",
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text("اربط حساب MT5 DEMO من التطبيق.")
                            )
                            .padding(.vertical, 30)
                        }

                        if let readiness = appModel.snapshot?.readiness {
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader("الجاهزية")
                                    readinessRow("MT5", readiness.connected)
                                    readinessRow("التداول", readiness.tradeAllowed && readiness.accountTradeAllowed)
                                    readinessRow("Expert", readiness.tradeExpert)
                                }
                            }
                        }

                        SurfaceCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Label("اتصال التطبيق", systemImage: "lock.shield.fill")
                                    Spacer()
                                    StatusPill(title: "متصل وآمن", isPositive: true)
                                }

                                Button {
                                    showLogin = true
                                } label: {
                                    Label("ربط حساب MT5 DEMO", systemImage: "person.badge.key")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(T4Palette.accent)
                                .disabled(appModel.snapshot?.engine.running == true)

                                Button("نسيان بيانات الدخول", role: .destructive) {
                                    showDisconnect = true
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("الحساب")
            .sheet(isPresented: $showLogin) {
                MT5LoginView()
            }
            .confirmationDialog(
                "نسيان بيانات الدخول؟",
                isPresented: $showDisconnect,
                titleVisibility: .visible
            ) {
                Button("نسيان", role: .destructive) {
                    appModel.disconnect()
                    connectionStore.clear()
                }
                Button("إلغاء", role: .cancel) {}
            }
        }
    }

    private func accountMetric(_ title: String, _ value: Double, _ currency: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: currency)))
                .font(.headline.monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readinessRow(_ title: String, _ value: Bool) -> some View {
        HStack {
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(value ? .green : .red)
            Text(title)
            Spacer()
            Text(value ? "جاهز" : "غير جاهز")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                Section("بيانات MT5") {
                    TextField("Broker / Server", text: $server)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Login", text: $login)
                        .keyboardType(.numberPad)

                    SecureField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        guard let loginNumber = Int64(login), !server.isEmpty, !password.isEmpty else {
                            appModel.errorMessage = "تحقق من بيانات MT5."
                            return
                        }

                        Task {
                            let success = await appModel.login(
                                server: server,
                                login: loginNumber,
                                password: password
                            )
                            password = ""
                            if success { dismiss() }
                        }
                    } label: {
                        Label("تسجيل الدخول", systemImage: "lock.open.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appModel.isPerformingCommand)
                } footer: {
                    Text("كلمة مرور MT5 لا تحفظ داخل التطبيق.")
                }
            }
            .t4ListBackground()
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
