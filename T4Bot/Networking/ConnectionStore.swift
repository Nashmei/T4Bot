import Foundation

@MainActor
final class ConnectionStore: ObservableObject {
    private enum Keys {
        static let tokenAccount = "control-api-token"
    }

    @Published var password: String
    @Published var validationMessage: String?
    @Published private(set) var isConfigured: Bool

    init() {
        let storedToken = KeychainStore.read(account: Keys.tokenAccount) ?? ""
        password = storedToken
        isConfigured = APIConfiguration(token: storedToken) != nil
    }

    var serverDisplayName: String {
        APIConfiguration.serverURL.host ?? "54-227-12-124.nip.io"
    }

    var configuration: APIConfiguration? {
        guard isConfigured else { return nil }
        return APIConfiguration(token: password)
    }

    var candidateConfiguration: APIConfiguration? {
        APIConfiguration(token: password)
    }

    @discardableResult
    func save() -> Bool {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard APIConfiguration(token: trimmed) != nil else {
            validationMessage = "أدخل كلمة المرور."
            return false
        }

        do {
            try KeychainStore.save(trimmed, account: Keys.tokenAccount)
            password = trimmed
            validationMessage = nil
            isConfigured = true
            return true
        } catch {
            validationMessage = "تعذر حفظ بيانات الدخول في iOS Keychain."
            isConfigured = false
            return false
        }
    }

    func clear() {
        KeychainStore.delete(account: Keys.tokenAccount)
        password = ""
        validationMessage = nil
        isConfigured = false
    }
}
