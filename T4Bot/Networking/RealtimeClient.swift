import Foundation

struct RealtimeEvent: Sendable {
    let type: String
    let payload: [String: JSONValue]
}

enum RealtimeUpdate: Sendable {
    case snapshot(ServerSnapshot)
    case event(RealtimeEvent)
    case invalidation
}

final class RealtimeClient {
    private var socketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    func connect(
        using configuration: APIConfiguration,
        onUpdate: @escaping @Sendable (RealtimeUpdate) -> Void
    ) {
        disconnect()

        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard let request = configuration.webSocketRequest(path: "/v1/ws") else {
                    return
                }

                let socket = URLSession.shared.webSocketTask(with: request)
                socketTask = socket
                socket.resume()

                do {
                    while !Task.isCancelled {
                        let message = try await socket.receive()
                        guard let data = Self.data(from: message) else {
                            onUpdate(.invalidation)
                            continue
                        }

                        if let snapshot = Self.snapshot(from: data) {
                            onUpdate(.snapshot(snapshot))
                        } else if let event = Self.event(from: data) {
                            onUpdate(.event(event))
                        } else {
                            onUpdate(.invalidation)
                        }
                    }
                } catch {
                    socket.cancel(with: .goingAway, reason: nil)
                    socketTask = nil
                    if Task.isCancelled { return }
                    try? await Task.sleep(for: .milliseconds(75))
                }
            }
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
    }

    deinit {
        disconnect()
    }

    private static func data(from message: URLSessionWebSocketTask.Message) -> Data? {
        switch message {
        case .data(let data): return data
        case .string(let string): return string.data(using: .utf8)
        @unknown default: return nil
        }
    }

    private static func snapshot(from data: Data) -> ServerSnapshot? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["type"] as? String == "snapshot",
            let payload = object["payload"],
            JSONSerialization.isValidJSONObject(payload),
            let payloadData = try? JSONSerialization.data(withJSONObject: payload)
        else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(ServerSnapshot.self, from: payloadData)
    }

    private static func event(from data: Data) -> RealtimeEvent? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String,
            type != "snapshot",
            let payload = object["payload"] as? [String: Any],
            JSONSerialization.isValidJSONObject(payload),
            let payloadData = try? JSONSerialization.data(withJSONObject: payload),
            let values = try? JSONDecoder().decode([String: JSONValue].self, from: payloadData)
        else { return nil }

        return RealtimeEvent(type: type, payload: values)
    }
}
