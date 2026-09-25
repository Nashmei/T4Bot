import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var connectionStore: ConnectionStore
    @EnvironmentObject private var appModel: AppModel
    @FocusState private var passwordFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 72)

                        VStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [T4Palette.accent, T4Palette.accent2],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 88, height: 88)
                                    .shadow(color: T4Palette.accent.opacity(0.28), radius: 24, y: 10)

                                Image(systemName: "waveform.path.ecg.rectangle.fill")
                                    .font(.system(size: 35, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            VStack(spacing: 6) {
                                Text("T4Bot")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                Text("تحكم لحظي • تحليل AI • صفقات MT5")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        SurfaceCard {
                            VStack(spacing: 16) {
                                HStack(spacing: 10) {
                                    Image(systemName: "bolt.horizontal.circle.fill")
                                        .foregroundStyle(T4Palette.accent2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("اتصال مباشر")
                                            .font(.subheadline.weight(.semibold))
                                        Text("مشفر وآمن")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusPill(title: "جاهز", isPositive: true)
                                }

                                SecureField("كلمة المرور", text: $connectionStore.password)
                                    .textContentType(.password)
                                    .submitLabel(.go)
                                    .focused($passwordFocused)
                                    .padding(14)
                                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
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
                                        Text("دخول")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(T4Palette.accent)
                                .disabled(
                                    appModel.isPerformingCommand ||
                                    connectionStore.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                )
                            }
                        }

                        Text("بيانات الدخول تحفظ في iOS Keychain فقط.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                }
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
                connectionStore.validationMessage = "تعذر تسجيل الدخول. تحقق من كلمة المرور والاتصال."
                return
            }

            guard connectionStore.save() else { return }
            appModel.connect(using: configuration)
        }
    }
}
