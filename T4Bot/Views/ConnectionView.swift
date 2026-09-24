import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var connectionStore: ConnectionStore
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)

                        Text("اتصال T4Bot")
                            .font(.title2.bold())

                        Text("يتصل التطبيق بمحرك Mtbot عبر HTTPS فقط. لا تحفظ بيانات MT5 داخل التطبيق.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("الخادم") {
                    TextField("https://bot.example.com", text: $connectionStore.baseURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    SecureField("رمز CONTROL_API_TOKEN", text: $connectionStore.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let validationMessage = connectionStore.validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        guard let configuration = connectionStore.candidateConfiguration else {
                            connectionStore.validationMessage = "استخدم رابط HTTPS صالحاً وأدخل رمز الوصول."
                            return
                        }

                        Task {
                            guard await appModel.validateConnection(using: configuration) else {
                                connectionStore.validationMessage = "تعذر التحقق من الاتصال أو رمز الوصول."
                                return
                            }

                            guard connectionStore.save() else { return }
                            appModel.connect(using: configuration)
                        }
                    } label: {
                        Label("اتصال آمن", systemImage: "network.badge.shield.half.filled")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appModel.isPerformingCommand)
                }

                Section {
                    Text("رمز الوصول يُحفظ في iOS Keychain. التطبيق يرفض HTTP غير المشفر.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("T4Bot")
        }
    }
}
