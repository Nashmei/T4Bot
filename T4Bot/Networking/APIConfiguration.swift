import Foundation

struct APIConfiguration: Equatable, Sendable {
    let baseURL: URL
    let token: String

    init?(baseURLString: String, token: String) {
        let trimmedURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !trimmedToken.isEmpty,
            var components = URLComponents(string: trimmedURL),
            components.scheme?.lowercased() == "https",
            components.host != nil
        else {
            return nil
        }

        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = components.url else { return nil }

        self.baseURL = url
        self.token = trimmedToken
    }

    func url(path: String) -> URL {
        let clean = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appendingPathComponent(clean)
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
