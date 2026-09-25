import Foundation

struct APIConfiguration: Equatable, Sendable {
    static let serverURL = URL(string: "https://54-227-12-124.nip.io")!

    let baseURL: URL
    let token: String

    init?(token: String) {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return nil }
        self.baseURL = Self.serverURL
        self.token = trimmedToken
    }

    func url(path: String) -> URL {
        path
            .split(separator: "/")
            .reduce(baseURL) { partial, component in
                partial.appendingPathComponent(String(component))
            }
    }

    func webSocketRequest(path: String) -> URLRequest? {
        guard var components = URLComponents(url: url(path: path), resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "wss"
        guard let socketURL = components.url else { return nil }

        var request = URLRequest(url: socketURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        return request
    }
}
