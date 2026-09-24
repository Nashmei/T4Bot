import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: ServerSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isPerformingCommand = false
    @Published var errorMessage: String?
    @Published var operationMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let client = APIClient()
    private let realtime = RealtimeClient()
    private var configuration: APIConfiguration?
    private var pollingTask: Task<Void, Never>?

    func validateConnection(using configuration: APIConfiguration) async -> Bool {
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            snapshot = try await client.snapshot(using: configuration)
            lastUpdated = Date()
            errorMessage = nil
            return true
        } catch {
            snapshot = nil
            errorMessage = localized(error)
            return false
        }
    }

    func connect(using configuration: APIConfiguration) {
        self.configuration = configuration
        errorMessage = nil
        operationMessage = nil

        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self?.refresh()
            }
        }

        realtime.connect(using: configuration) { [weak self] update in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch update {
                case .snapshot(let liveSnapshot):
                    self.snapshot = liveSnapshot
                    self.lastUpdated = Date()
                    self.errorMessage = nil
                case .invalidation:
                    await self.refresh()
                }
            }
        }
    }

    func disconnect() {
        pollingTask?.cancel()
        pollingTask = nil
        realtime.disconnect()
        configuration = nil
        snapshot = nil
        lastUpdated = nil
        errorMessage = nil
        operationMessage = nil
    }

    func refresh() async {
        guard let configuration, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            snapshot = try await client.snapshot(using: configuration)
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = localized(error)
        }
    }

    func startEngine() async {
        await performCommand {
            try await client.startEngine(using: $0)
        }
    }

    func stopEngine() async {
        await performCommand {
            try await client.stopEngine(using: $0)
        }
    }

    func runAnalysis() async {
        guard let configuration else { return }
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            _ = try await client.runAnalysis(using: configuration)
            operationMessage = "اكتمل التحليل."
            await refresh()
        } catch {
            errorMessage = localized(error)
        }
    }

    func update(settings: TradingSettings) async {
        guard let configuration else { return }
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            let response = try await client.updateSettings(settings, using: configuration)
            operationMessage = response.message
            await refresh()
        } catch {
            errorMessage = localized(error)
        }
    }

    func update(symbols: [String]) async {
        guard let configuration else { return }
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            _ = try await client.updateSymbols(symbols, using: configuration)
            operationMessage = "تم تحديث الأزواج."
            await refresh()
        } catch {
            errorMessage = localized(error)
        }
    }

    func login(server: String, login: Int64, password: String) async -> Bool {
        guard let configuration else { return false }
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            let response = try await client.login(
                server: server,
                login: login,
                password: password,
                using: configuration
            )
            operationMessage = response.message
            await refresh()
            return response.ok
        } catch {
            errorMessage = localized(error)
            return false
        }
    }

    private func performCommand(
        _ action: (APIConfiguration) async throws -> CommandResponse
    ) async {
        guard let configuration else { return }
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            let response = try await action(configuration)
            operationMessage = response.message
            await refresh()
        } catch {
            errorMessage = localized(error)
        }
    }

    private func localized(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
