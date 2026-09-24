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
    @Published private(set) var isConfigured: Bool

    init() {
        let storedURL = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        let storedToken = KeychainStore.read(account: Keys.tokenAccount) ?? ""
        baseURLString = storedURL
        token = storedToken
        isConfigured = APIConfiguration(baseURLString: storedURL, token: storedToken) != nil
    }

    /// The active, persisted connection used by the app after a successful save.
    var configuration: APIConfiguration? {
        guard isConfigured else { return nil }
        return APIConfiguration(baseURLString: baseURLString, token: token)
    }

    /// A draft connection built from the fields currently being edited.
    var candidateConfiguration: APIConfiguration? {
        APIConfiguration(baseURLString: baseURLString, token: token)
    }

    @discardableResult
    func save() -> Bool {
        guard candidateConfiguration != nil else {
            validationMessage = "استخدم رابط HTTPS صالحاً وأدخل رمز الوصول."
            return false
        }

        do {
            UserDefaults.standard.set(
                baseURLString.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: Keys.baseURL
            )
            try KeychainStore.save(
                token.trimmingCharacters(in: .whitespacesAndNewlines),
                account: Keys.tokenAccount
            )
            validationMessage = nil
            isConfigured = true
            return true
        } catch {
            validationMessage = "تعذر حفظ رمز الوصول في Keychain."
            isConfigured = false
            return false
        }
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Keys.baseURL)
        KeychainStore.delete(account: Keys.tokenAccount)
        baseURLString = ""
        token = ""
        validationMessage = nil
        isConfigured = false
    }
}
