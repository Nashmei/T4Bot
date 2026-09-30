import Foundation

struct ServerSnapshot: Codable, Equatable, Sendable {
    let serverTime: Double
    let engine: EngineSnapshot
    let account: AccountSnapshot?
    let positions: [PositionSnapshot]
    let settings: TradingSettings
    let analysis: [AnalysisSnapshot]
    let readiness: ReadinessSnapshot
    let accountGuard: AccountGuardSnapshot?
    let strategyStats: [StrategyStat]?
}

struct EngineSnapshot: Codable, Equatable, Sendable {
    let running: Bool
    let scanCount: Int
    let lastCycleSeconds: Double
    let lastCycleAt: Double
    let trackedPositions: Int
    let maxPositions: Int
    let sessionStartBalance: Double?
    let sessionProfit: Double?
    let sessionProfitHit: Bool?
    let selectedStrategy: String?
    let currentRegime: String?
    let lastDecision: String?
}

struct AccountSnapshot: Codable, Equatable, Sendable {
    let login: Int64
    let server: String
    let currency: String
    let balance: Double
    let equity: Double
    let margin: Double
    let marginFree: Double
    let profit: Double
    let isDemo: Bool
}

struct PositionSnapshot: Codable, Equatable, Identifiable, Sendable {
    let ticket: Int64
    let symbol: String
    let side: String
    let volume: Double
    let priceOpen: Double
    let priceCurrent: Double
    let sl: Double
    let tp: Double
    let profit: Double
    let magic: Int
    let imageId: String?
    let strategy: String?
    let regime: String?
    let riskCash: Double?
    let riskPct: Double?
    var id: Int64 { ticket }
}

struct ClosedTrade: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let ticket: Int64
    let symbol: String
    let side: String
    let strategy: String
    let openedAt: Double
    let closedAt: Double
    let entry: Double
    let exit: Double
    let sl: Double
    let tp: Double
    let volume: Double
    let pnl: Double
    let result: String
    let reason: String
    let imageId: String?
    let regime: String?
    let rMultiple: Double?
}

struct TradingSettings: Codable, Equatable, Sendable {
    var symbols: [String]
    var riskPct: Double
    var maxPositions: Int
    var maxConsecutiveLosses: Int
    var dailyLossLimitPct: Double
    var sessionProfitLimit: Double
    var realTradingEnabled: Bool

    // Legacy fields kept for backward compatibility with older servers.
    var rr: Double
    var slPoints: Double
    var tpPoints: Double
    var minConfidence: Double
    var protectionPct: Double
    var trailingTriggerPct: Double
    var trailingGapPct: Double

    static let defaults = TradingSettings(
        symbols: ["EURUSD"],
        riskPct: 0.25,
        maxPositions: 1,
        maxConsecutiveLosses: 3,
        dailyLossLimitPct: 2,
        sessionProfitLimit: 0,
        realTradingEnabled: false,
        rr: 0,
        slPoints: 0,
        tpPoints: 0,
        minConfidence: 0,
        protectionPct: 0,
        trailingTriggerPct: 0,
        trailingGapPct: 0
    )
}

struct ReadinessSnapshot: Codable, Equatable, Sendable {
    let connected: Bool
    let tradeAllowed: Bool
    let accountTradeAllowed: Bool
    let tradeExpert: Bool
    var ready: Bool { connected && tradeAllowed && accountTradeAllowed && tradeExpert }
}

struct AccountGuardSnapshot: Codable, Equatable, Sendable {
    let blocked: Bool
    let reason: String?
    let dailyPnl: Double?
    let drawdownPct: Double?
    let consecutiveLosses: Int?
}

struct StrategyStat: Codable, Equatable, Identifiable, Sendable {
    let strategy: String
    let symbol: String?
    let regime: String?
    let trades: Int?
    let winRate: Double?
    let profitFactor: Double?
    let expectancyR: Double?
    let enabled: Bool?
    var id: String { [strategy, symbol ?? "", regime ?? ""].joined(separator: "|") }
}

struct AnalysisSnapshot: Codable, Equatable, Identifiable, Sendable {
    let symbol: String
    let regime: String
    let state: String
    let side: String?
    let strategy: String?
    let confidence: Double?
    let reason: String?
    let updatedAt: Double
    let direction: String?
    let strength: Double?
    let reasonCode: String?
    let evaluatedCount: Int?
    var id: String { symbol }
}

struct CommandResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let message: String
}

struct LoginRequest: Codable, Sendable {
    let server: String
    let login: Int64
    let password: String
}

struct LoginResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let message: String
    let account: AccountSnapshot?
}

struct TradingSettingsPatch: Codable, Sendable {
    let riskPct: Double
    let maxPositions: Int
    let maxConsecutiveLosses: Int
    let dailyLossLimitPct: Double
    let sessionProfitLimit: Double
    let realTradingEnabled: Bool
    let rr: Double
    let slPoints: Double
    let tpPoints: Double
    let minConfidence: Double
    let protectionPct: Double
    let trailingTriggerPct: Double
    let trailingGapPct: Double

    init(_ v: TradingSettings) {
        riskPct = v.riskPct
        maxPositions = v.maxPositions
        maxConsecutiveLosses = v.maxConsecutiveLosses
        dailyLossLimitPct = v.dailyLossLimitPct
        sessionProfitLimit = v.sessionProfitLimit
        realTradingEnabled = v.realTradingEnabled
        rr = v.rr
        slPoints = v.slPoints
        tpPoints = v.tpPoints
        minConfidence = v.minConfidence
        protectionPct = v.protectionPct
        trailingTriggerPct = v.trailingTriggerPct
        trailingGapPct = v.trailingGapPct
    }
}

struct SymbolsUpdateRequest: Codable, Sendable { let symbols: [String] }

struct SymbolsResponse: Codable, Equatable, Sendable {
    let selected: [String]
    let active: [String]?
    let available: [String]
    let total: Int?
    let hasMore: Bool?
}

struct AuditEntry: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let ts: Double
    let event: String
    let symbol: String
    let details: [String: JSONValue]
    var displayID: Int { id }
}

enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}
