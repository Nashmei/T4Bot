import SwiftUI
import UIKit

struct AccountView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showLogin = false

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    accountPanel
                    readinessPanel
                    controlsPanel
                }
                .padding(16)
            }
        }
        .navigationTitle("الحساب")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogin) { MT5LoginView() }
    }

    @ViewBuilder
    private var accountPanel: some View {
        if let a = appModel.snapshot?.account {
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(a.login)").font(.title3.bold().monospaced())
                            Text(a.server).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusDot(text: a.isDemo ? "Demo" : "Real", color: a.isDemo ? T4Palette.cyan : T4Palette.warning)
                    }
                    Divider()
                    value("Balance", a.balance, a.currency)
                    value("Equity", a.equity, a.currency)
                    value("Free Margin", a.marginFree, a.currency)
                    value("Floating PnL", a.profit, a.currency, tint: a.profit >= 0 ? T4Palette.positive : T4Palette.negative)
                }
            }
        } else {
            ContentUnavailableView("MT5 غير متصل", systemImage: "person.crop.circle.badge.exclamationmark")
        }
    }

    private var readinessPanel: some View {
        let r = appModel.snapshot?.readiness
        return Panel {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("جاهزية التداول")
                StatusDot(text: "اتصال MT5", color: r?.connected == true ? T4Palette.positive : T4Palette.negative)
                StatusDot(text: "Trade allowed", color: r?.tradeAllowed == true ? T4Palette.positive : T4Palette.negative)
                StatusDot(text: "Account trade allowed", color: r?.accountTradeAllowed == true ? T4Palette.positive : T4Palette.negative)
                StatusDot(text: "Expert / Algo", color: r?.tradeExpert == true ? T4Palette.positive : T4Palette.negative)
            }
        }
    }

    private var controlsPanel: some View {
        Panel {
            VStack(spacing: 10) {
                NavigationLink { SettingsView() } label: {
                    Label("إعدادات المخاطرة والحدود", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)

                Button {
                    showLogin = true
                } label: {
                    Label("تغيير حساب MT5", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(T4Palette.accent)
                .disabled(appModel.snapshot?.engine.running == true)
            }
        }
    }

    private func value(_ title: String, _ number: Double, _ currency: String, tint: Color = .primary) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(number.formatted(.currency(code: currency))).font(.headline.monospacedDigit()).foregroundStyle(tint)
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
            ZStack {
                AppBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        BrandMark(size: 64, running: false)
                        Panel {
                            VStack(spacing: 12) {
                                field("السيرفر") { TextField("MetaQuotes-Demo", text: $server).textInputAutocapitalization(.never).autocorrectionDisabled() }
                                field("رقم الحساب") { TextField("Login", text: $login).keyboardType(.numberPad) }
                                field("كلمة المرور") { SecureField("Password", text: $password) }
                            }
                        }
                        Button("ربط الحساب") {
                            guard let n = Int64(login), !server.isEmpty, !password.isEmpty else {
                                appModel.errorMessage = "تحقق من بيانات MT5."
                                return
                            }
                            Task {
                                let ok = await appModel.login(server: server, login: n, password: password)
                                password = ""
                                if ok { dismiss() }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(T4Palette.accent)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("ربط MT5")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { password = ""; dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }

    private func field<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content().padding(12).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
