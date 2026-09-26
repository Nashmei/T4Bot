import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum ConnectionState: String {
        case live
        case reconnecting
        case offline
    }

    @Published private(set) var snapshot: ServerSnapshot?
    @Published private(set) var tradeHistory: [ClosedTrade] = []
    @Published private(set) var availableSymbols: [String] = []
    @Published private(set) var activeSymbols: [String] = []
    @Published private(set) var symbolsHasMore = false
    @Published private(set) var symbolsTotal = 0
    @Published private(set) var connectionState: ConnectionState = .offline
    @Published private(set) var isRefreshing = false
    @Published private(set) var isPerformingCommand = false
    @Published var errorMessage: String?
    @Published var operationMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let client = APIClient()
    private let realtime = RealtimeClient()
    private let notifications = NotificationManager.shared

    private var configuration: APIConfiguration?
    private var fallbackTask: Task<Void, Never>?
    private var reconnectIndicatorTask: Task<Void, Never>?
    private var isAppActive = true
    private var lastFallbackAttempt = Date.distantPast
    private var symbolQuery = ""
    private let symbolPageSize = 200

    func validateConnection(using configuration: APIConfiguration) async -> Bool {
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            snapshot = try await client.snapshot(using: configuration)
            lastUpdated = Date()
            errorMessage = nil
            connectionState = .live
            return true
        } catch {
            snapshot = nil
            connectionState = .offline
            errorMessage = localized(error)
            return false
        }
    }

    func connect(using configuration: APIConfiguration) {
        self.configuration = configuration
        errorMessage = nil
        operationMessage = nil

        startRealtime(markReconnecting: true)
        startFallbackRefresh()

        Task {
            await loadHistory(silent: true)
            await notifications.requestAuthorization()
        }
    }

    func disconnect() {
        reconnectIndicatorTask?.cancel()
        reconnectIndicatorTask = nil
        fallbackTask?.cancel()
        fallbackTask = nil
        realtime.disconnect()

        configuration = nil
        snapshot = nil
        tradeHistory = []
        availableSymbols = []
        activeSymbols = []
        symbolsHasMore = false
        symbolsTotal = 0
        symbolQuery = ""
        lastUpdated = nil
        errorMessage = nil
        operationMessage = nil
        connectionState = .offline

        Task { await notifications.endLiveActivity() }
    }

    func sceneBecameInactive() {
        isAppActive = false
        reconnectIndicatorTask?.cancel()
        reconnectIndicatorTask = nil
        fallbackTask?.cancel()
        fallbackTask = nil
    }

    func sceneBecameActive() {
        guard configuration != nil else { return }

        isAppActive = true
        errorMessage = nil

        let previousUpdate = lastUpdated
        startRealtime(markReconnecting: false)
        startFallbackRefresh()

        reconnectIndicatorTask?.cancel()
        reconnectIndicatorTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            if self.lastUpdated == previousUpdate {
                self.connectionState = .reconnecting
            }
        }

        Task {
            await refresh(silent: true)
            await loadHistory(silent: true)
        }
    }

    func refresh(silent: Bool = false) async {
        guard let configuration, !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            snapshot = try await client.snapshot(using: configuration)
            lastUpdated = Date()
            connectionState = .live
            reconnectIndicatorTask?.cancel()
            reconnectIndicatorTask = nil
            if !silent { errorMessage = nil }
        } catch {
            if isAppActive { connectionState = .reconnecting }
            if !silent && isAppActive { errorMessage = localized(error) }
        }
    }

    func refreshSupportingData(silent: Bool = false) async {
        await loadHistory(silent: silent)
    }

    func loadHistory(silent: Bool = false) async {
        guard let configuration else { return }
        do {
            tradeHistory = try await client.tradeHistory(limit: 500, using: configuration)
        } catch {
            if !silent && isAppActive { errorMessage = localized(error) }
        }
    }

    func loadSymbols(
        silent: Bool = false,
        force: Bool = false,
        query: String = ""
    ) async {
        guard let configuration else { return }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !force && normalized == symbolQuery && !availableSymbols.isEmpty { return }

        do {
            let response = try await client.symbols(
                query: normalized,
                limit: symbolPageSize,
                offset: 0,
                using: configuration
            )
            symbolQuery = normalized
            availableSymbols = response.available
            activeSymbols = response.active ?? []
            symbolsTotal = response.total ?? response.available.count
            symbolsHasMore = response.hasMore ?? false
        } catch {
            if !silent && isAppActive { errorMessage = localized(error) }
        }
    }

    func loadMoreSymbols(silent: Bool = false) async {
        guard let configuration, symbolsHasMore else { return }
        do {
            let response = try await client.symbols(
                query: symbolQuery,
                limit: symbolPageSize,
                offset: availableSymbols.count,
                using: configuration
            )
            var merged = availableSymbols
            for symbol in response.available where !merged.contains(symbol) {
                merged.append(symbol)
            }
            availableSymbols = merged
            activeSymbols = response.active ?? activeSymbols
            symbolsTotal = response.total ?? symbolsTotal
            symbolsHasMore = response.hasMore ?? false
        } catch {
            if !silent && isAppActive { errorMessage = localized(error) }
        }
    }

    func tradeImage(mediaID: String) async -> Data? {
        guard let configuration else { return nil }
        return try? await client.tradeImage(mediaID: mediaID, using: configuration)
    }

    func startEngine() async {
        await performCommand { try await client.startEngine(using: $0) }
    }

    func stopEngine() async {
        await performCommand { try await client.stopEngine(using: $0) }
    }

    func runAnalysis() async {
        guard let configuration else { return }
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            _ = try await client.runAnalysis(using: configuration)
            operationMessage = "تم تحديث التحليل."
            await refresh(silent: true)
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
            await refresh(silent: true)
        } catch {
            errorMessage = localized(error)
        }
    }

    func update(symbols: [String]) async {
        guard let configuration else { return }
        isPerformingCommand = true
        defer { isPerformingCommand = false }

        do {
            let response = try await client.updateSymbols(symbols, using: configuration)
            availableSymbols = response.available
            activeSymbols = response.active ?? activeSymbols
            symbolsTotal = response.total ?? response.available.count
            symbolsHasMore = response.hasMore ?? false
            symbolQuery = ""
            operationMessage = "تم تحديث الأسواق."
            await refresh(silent: true)
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
            await refresh(silent: true)
            await loadHistory(silent: true)
            return response.ok
        } catch {
            errorMessage = localized(error)
            return false
        }
    }

    private func startRealtime(markReconnecting: Bool) {
        guard let configuration, isAppActive else { return }

        if markReconnecting { connectionState = .reconnecting }

        realtime.connect(using: configuration) { [weak self] update in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch update {
                case .snapshot(let liveSnapshot):
                    self.snapshot = liveSnapshot
                    self.lastUpdated = Date()
                    self.connectionState = .live
                    self.reconnectIndicatorTask?.cancel()
                    self.reconnectIndicatorTask = nil
                    self.errorMessage = nil

                case .event(let event):
                    await self.notifications.handle(event: event, account: self.snapshot?.account)
                    if event.type == "trade_closed" {
                        await self.loadHistory(silent: true)
                    } else if event.type == "session_profit_limit" {
                        await self.refresh(silent: true)
                    }

                case .invalidation:
                    await self.refresh(silent: true)
                }
            }
        }
    }

    private func startFallbackRefresh() {
        fallbackTask?.cancel()

        fallbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }

                let stale = self.lastUpdated.map { Date().timeIntervalSince($0) > 3.0 } ?? true
                guard stale, Date().timeIntervalSince(self.lastFallbackAttempt) >= 3.0 else { continue }

                self.lastFallbackAttempt = Date()
                self.connectionState = .reconnecting
                await self.refresh(silent: true)
            }
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
            await refresh(silent: true)
        } catch {
            errorMessage = localized(error)
        }
    }

    private func localized(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
