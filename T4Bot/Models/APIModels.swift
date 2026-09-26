import Foundation

struct ServerSnapshot: Codable, Equatable, Sendable {
    let serverTime: Double
    let engine: EngineSnapshot
    let account: AccountSnapshot?
    let positions: [PositionSnapshot]
    let settings: TradingSettings
    let analysis: [AnalysisSnapshot]
    let readiness: ReadinessSnapshot
}

struct EngineSnapshot: Codable, Equatable, Sendable {
    let running: Bool
    let scanCount: Int
    let lastCycleSeconds: Double
    let lastCycleAt: Double
    let trackedPositions: Int
    let maxPositions: Int
    let sessionStartBalance: Double
    let sessionProfit: Double
    let sessionProfitHit: Bool
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
}

struct TradingSettings: Codable, Equatable, Sendable {
    var symbols: [String]
    var riskPct: Double
    var rr: Double
    var slPoints: Double
    var tpPoints: Double
    var minConfidence: Double
    var protectionPct: Double
    var trailingGapPct: Double
    var maxTradeMinutes: Double
    var maxPositions: Int
    var maxConsecutiveLosses: Int
    var dailyLossLimitPct: Double
    var sessionProfitLimit: Double

    static let defaults = TradingSettings(
        symbols: ["EURUSD"],
        riskPct: 0.25,
        rr: 0,
        slPoints: 0,
        tpPoints: 0,
        minConfidence: 75,
        protectionPct: 0,
        trailingGapPct: 0,
        maxTradeMinutes: 0,
        maxPositions: 1,
        maxConsecutiveLosses: 3,
        dailyLossLimitPct: 2,
        sessionProfitLimit: 0
    )
}

struct ReadinessSnapshot: Codable, Equatable, Sendable {
    let connected: Bool
    let tradeAllowed: Bool
    let accountTradeAllowed: Bool
    let tradeExpert: Bool

    var ready: Bool {
        connected && tradeAllowed && accountTradeAllowed && tradeExpert
    }
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
    let rr: Double
    let slPoints: Double
    let tpPoints: Double
    let minConfidence: Double
    let protectionPct: Double
    let trailingGapPct: Double
    let maxTradeMinutes: Double
    let maxPositions: Int
    let maxConsecutiveLosses: Int
    let dailyLossLimitPct: Double
    let sessionProfitLimit: Double

    init(_ value: TradingSettings) {
        riskPct = value.riskPct
        rr = value.rr
        slPoints = value.slPoints
        tpPoints = value.tpPoints
        minConfidence = value.minConfidence
        protectionPct = value.protectionPct
        trailingGapPct = value.trailingGapPct
        maxTradeMinutes = value.maxTradeMinutes
        maxPositions = value.maxPositions
        maxConsecutiveLosses = value.maxConsecutiveLosses
        dailyLossLimitPct = value.dailyLossLimitPct
        sessionProfitLimit = value.sessionProfitLimit
    }
}

struct SymbolsUpdateRequest: Codable, Sendable {
    let symbols: [String]
}

struct SymbolsResponse: Codable, Equatable, Sendable {
    let selected: [String]
    let available: [String]
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
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}


