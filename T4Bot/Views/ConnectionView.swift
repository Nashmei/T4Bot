import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var connectionStore: ConnectionStore
    @EnvironmentObject private var appModel: AppModel
    @FocusState private var passwordFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(.tint.opacity(0.12))
                            .frame(width: 82, height: 82)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.tint)
                    }

                    VStack(spacing: 6) {
                        Text("T4Bot")
                            .font(.largeTitle.bold())
                        Text("تحكم لحظي • تحليل AI • صفقات MT5")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer().frame(height: 42)

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("الخادم")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(connectionStore.serverDisplayName)
                                .font(.subheadline.monospaced())
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    .padding(14)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    SecureField("كلمة المرور", text: $connectionStore.password)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($passwordFocused)
                        .padding(14)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .onSubmit { login() }

                    if let message = connectionStore.validationMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: login) {
                        HStack {
                            if appModel.isPerformingCommand {
                                ProgressView().controlSize(.small)
                            }
                            Text("تسجيل الدخول")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.isPerformingCommand || connectionStore.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Text("الاتصال مشفّر عبر HTTPS. تحفظ بيانات الدخول في iOS Keychain فقط.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private func login() {
        passwordFocused = false

        guard let configuration = connectionStore.candidateConfiguration else {
            connectionStore.validationMessage = "أدخل كلمة المرور."
            return
        }

        Task {
            guard await appModel.validateConnection(using: configuration) else {
                connectionStore.validationMessage = "كلمة المرور غير صحيحة أو الخادم غير متاح."
                return
            }

            guard connectionStore.save() else { return }
            appModel.connect(using: configuration)
        }
    }
}
