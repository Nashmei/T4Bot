import Foundation

@MainActor
final class ConnectionStore: ObservableObject {
    private enum Keys {
        static let baseURL = "t4bot.api.baseURL"
        static let tokenAccount = "control-api-token"
    }

    @Published var baseURLString: String
    @Published var token: String
    @Published var validationMessage: String?

    init() {
        baseURLString = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        token = KeychainStore.read(account: Keys.tokenAccount) ?? ""
    }

    var configuration: APIConfiguration? {
        APIConfiguration(baseURLString: baseURLString, token: token)
    }

    var isConfigured: Bool {
        configuration != nil
    }

    @discardableResult
    func save() -> Bool {
        guard configuration != nil else {
            validationMessage = "استخدم رابط HTTPS صالحاً وأدخل رمز الوصول."
            return false
        }

        do {
            UserDefaults.standard.set(baseURLString.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.baseURL)
            try KeychainStore.save(token.trimmingCharacters(in: .whitespacesAndNewlines), account: Keys.tokenAccount)
            validationMessage = nil
            return true
        } catch {
            validationMessage = "تعذر حفظ رمز الوصول في Keychain."
            return false
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Keys.baseURL)
        KeychainStore.delete(account: Keys.tokenAccount)
        baseURLString = ""
        token = ""
        validationMessage = nil
    }
}
