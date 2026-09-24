import Foundation

final class RealtimeClient {
    private var socketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    func connect(
        using configuration: APIConfiguration,
        onEvent: @escaping @Sendable () -> Void
    ) {
        disconnect()

        guard let request = configuration.webSocketRequest(path: "/v1/ws") else {
            return
        }

        let socket = URLSession.shared.webSocketTask(with: request)
        socketTask = socket
        socket.resume()

        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    _ = try await socket.receive()
                    onEvent()
                } catch {
                    break
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
}
