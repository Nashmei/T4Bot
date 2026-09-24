import Foundation

actor APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    func snapshot(using configuration: APIConfiguration) async throws -> ServerSnapshot {
        try await request(path: "/v1/snapshot", method: "GET", configuration: configuration)
    }

    func startEngine(using configuration: APIConfiguration) async throws -> CommandResponse {
        try await request(path: "/v1/engine/start", method: "POST", configuration: configuration)
    }

    func stopEngine(using configuration: APIConfiguration) async throws -> CommandResponse {
        try await request(path: "/v1/engine/stop", method: "POST", configuration: configuration)
    }

    func runAnalysis(using configuration: APIConfiguration) async throws -> [AnalysisSnapshot] {
        try await request(path: "/v1/analysis/run", method: "POST", configuration: configuration)
    }

    func updateSettings(_ settings: TradingSettings, using configuration: APIConfiguration) async throws -> CommandResponse {
        try await request(
            path: "/v1/settings",
            method: "PATCH",
            body: TradingSettingsPatch(settings),
            configuration: configuration
        )
    }

    func updateSymbols(_ symbols: [String], using configuration: APIConfiguration) async throws -> SymbolsResponse {
        try await request(
            path: "/v1/symbols",
            method: "PUT",
            body: SymbolsUpdateRequest(symbols: symbols),
            configuration: configuration
        )
    }

    func symbols(using configuration: APIConfiguration) async throws -> SymbolsResponse {
        try await request(path: "/v1/symbols", method: "GET", configuration: configuration)
    }

    func login(server: String, login: Int64, password: String, using configuration: APIConfiguration) async throws -> LoginResponse {
        try await request(
            path: "/v1/account/login",
            method: "POST",
            body: LoginRequest(server: server, login: login, password: password),
            configuration: configuration
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        configuration: APIConfiguration
    ) async throws -> Response {
        try await request(path: path, method: method, bodyData: nil, configuration: configuration)
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        configuration: APIConfiguration
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        return try await request(path: path, method: method, bodyData: bodyData, configuration: configuration)
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        bodyData: Data?,
        configuration: APIConfiguration
    ) async throws -> Response {
        var request = URLRequest(url: configuration.url(path: path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200..<300).contains(http.statusCode) else {
                let message = (try? decoder.decode(ServerErrorEnvelope.self, from: data).detail)
                    ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                throw APIError.server(statusCode: http.statusCode, message: message)
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }
}

private struct ServerErrorEnvelope: Decodable {
    let detail: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case transport(String)
    case server(statusCode: Int, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة الشبكة غير صالحة."
        case .transport(let message):
            return "تعذر الاتصال بالخادم: \(message)"
        case .server(let statusCode, let message):
            return "خطأ الخادم (\(statusCode)): \(message)"
        case .decoding(let message):
            return "استجابة الخادم غير متوافقة مع التطبيق: \(message)"
        }
    }
}
