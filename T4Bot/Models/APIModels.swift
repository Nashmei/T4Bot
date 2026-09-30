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

    private enum CodingKeys: String, CodingKey {
        case serverTime, engine, account, positions, settings, analysis, readiness, accountGuard, strategyStats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverTime = try c.decode(Double.self, forKey: .serverTime)
        engine = try c.decode(EngineSnapshot.self, forKey: .engine)
        account = try c.decodeIfPresent(AccountSnapshot.self, forKey: .account)
        positions = try c.decodeIfPresent([PositionSnapshot].self, forKey: .positions) ?? []
        settings = try c.decodeIfPresent(TradingSettings.self, forKey: .settings) ?? .defaults
        analysis = try c.decodeIfPresent([AnalysisSnapshot].self, forKey: .analysis) ?? []
        readiness = try c.decodeIfPresent(ReadinessSnapshot.self, forKey: .readiness) ?? .init(connected: false, tradeAllowed: false, accountTradeAllowed: false, tradeExpert: false)
        accountGuard = try c.decodeIfPresent(AccountGuardSnapshot.self, forKey: .accountGuard)
        strategyStats = try c.decodeIfPresent([StrategyStat].self, forKey: .strategyStats)
    }

    init(serverTime: Double, engine: EngineSnapshot, account: AccountSnapshot?, positions: [PositionSnapshot], settings: TradingSettings, analysis: [AnalysisSnapshot], readiness: ReadinessSnapshot, accountGuard: AccountGuardSnapshot? = nil, strategyStats: [StrategyStat]? = nil) {
        self.serverTime = serverTime; self.engine = engine; self.account = account; self.positions = positions; self.settings = settings; self.analysis = analysis; self.readiness = readiness; self.accountGuard = accountGuard; self.strategyStats = strategyStats
    }
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

    private enum CodingKeys: String, CodingKey {
        case running, scanCount, lastCycleSeconds, lastCycleAt, trackedPositions, maxPositions, sessionStartBalance, sessionProfit, sessionProfitHit, selectedStrategy, currentRegime, lastDecision
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        running = try c.decodeIfPresent(Bool.self, forKey: .running) ?? false
        scanCount = try c.decodeIfPresent(Int.self, forKey: .scanCount) ?? 0
        lastCycleSeconds = try c.decodeIfPresent(Double.self, forKey: .lastCycleSeconds) ?? 0
        lastCycleAt = try c.decodeIfPresent(Double.self, forKey: .lastCycleAt) ?? 0
        trackedPositions = try c.decodeIfPresent(Int.self, forKey: .trackedPositions) ?? 0
        maxPositions = try c.decodeIfPresent(Int.self, forKey: .maxPositions) ?? 0
        sessionStartBalance = try c.decodeIfPresent(Double.self, forKey: .sessionStartBalance)
        sessionProfit = try c.decodeIfPresent(Double.self, forKey: .sessionProfit)
        sessionProfitHit = try c.decodeIfPresent(Bool.self, forKey: .sessionProfitHit)
        selectedStrategy = try c.decodeIfPresent(String.self, forKey: .selectedStrategy)
        currentRegime = try c.decodeIfPresent(String.self, forKey: .currentRegime)
        lastDecision = try c.decodeIfPresent(String.self, forKey: .lastDecision)
    }

    init(running: Bool, scanCount: Int, lastCycleSeconds: Double, lastCycleAt: Double, trackedPositions: Int, maxPositions: Int, sessionStartBalance: Double? = nil, sessionProfit: Double? = nil, sessionProfitHit: Bool? = nil, selectedStrategy: String? = nil, currentRegime: String? = nil, lastDecision: String? = nil) {
        self.running = running; self.scanCount = scanCount; self.lastCycleSeconds = lastCycleSeconds; self.lastCycleAt = lastCycleAt; self.trackedPositions = trackedPositions; self.maxPositions = maxPositions; self.sessionStartBalance = sessionStartBalance; self.sessionProfit = sessionProfit; self.sessionProfitHit = sessionProfitHit; self.selectedStrategy = selectedStrategy; self.currentRegime = currentRegime; self.lastDecision = lastDecision
    }
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

    private enum CodingKeys: String, CodingKey { case ticket, symbol, side, volume, priceOpen, priceCurrent, sl, tp, profit, magic, imageId, strategy, regime, riskCash, riskPct }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ticket = try c.decode(Int64.self, forKey: .ticket); symbol = try c.decode(String.self, forKey: .symbol); side = try c.decode(String.self, forKey: .side)
        volume = try c.decode(Double.self, forKey: .volume); priceOpen = try c.decode(Double.self, forKey: .priceOpen); priceCurrent = try c.decode(Double.self, forKey: .priceCurrent)
        sl = try c.decode(Double.self, forKey: .sl); tp = try c.decode(Double.self, forKey: .tp); profit = try c.decode(Double.self, forKey: .profit); magic = try c.decode(Int.self, forKey: .magic)
        imageId = try c.decodeIfPresent(String.self, forKey: .imageId); strategy = try c.decodeIfPresent(String.self, forKey: .strategy); regime = try c.decodeIfPresent(String.self, forKey: .regime); riskCash = try c.decodeIfPresent(Double.self, forKey: .riskCash); riskPct = try c.decodeIfPresent(Double.self, forKey: .riskPct)
    }
    init(ticket: Int64, symbol: String, side: String, volume: Double, priceOpen: Double, priceCurrent: Double, sl: Double, tp: Double, profit: Double, magic: Int, imageId: String? = nil, strategy: String? = nil, regime: String? = nil, riskCash: Double? = nil, riskPct: Double? = nil) {
        self.ticket=ticket; self.symbol=symbol; self.side=side; self.volume=volume; self.priceOpen=priceOpen; self.priceCurrent=priceCurrent; self.sl=sl; self.tp=tp; self.profit=profit; self.magic=magic; self.imageId=imageId; self.strategy=strategy; self.regime=regime; self.riskCash=riskCash; self.riskPct=riskPct
    }
}

struct ClosedTrade: Codable, Equatable, Identifiable, Sendable {
    let id: Int; let ticket: Int64; let symbol: String; let side: String; let strategy: String
    let openedAt: Double; let closedAt: Double; let entry: Double; let exit: Double; let sl: Double; let tp: Double; let volume: Double; let pnl: Double
    let result: String; let reason: String; let imageId: String?; let regime: String?; let rMultiple: Double?

    private enum CodingKeys: String, CodingKey { case id,ticket,symbol,side,strategy,openedAt,closedAt,entry,exit,sl,tp,volume,pnl,result,reason,imageId,regime,rMultiple }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey:.id); ticket = try c.decode(Int64.self, forKey:.ticket); symbol = try c.decode(String.self, forKey:.symbol); side = try c.decode(String.self, forKey:.side)
        strategy = try c.decodeIfPresent(String.self, forKey:.strategy) ?? "unknown"; openedAt = try c.decode(Double.self, forKey:.openedAt); closedAt = try c.decode(Double.self, forKey:.closedAt)
        entry = try c.decode(Double.self, forKey:.entry); exit = try c.decode(Double.self, forKey:.exit); sl = try c.decode(Double.self, forKey:.sl); tp = try c.decode(Double.self, forKey:.tp); volume = try c.decode(Double.self, forKey:.volume); pnl = try c.decode(Double.self, forKey:.pnl)
        result = try c.decodeIfPresent(String.self, forKey:.result) ?? ""; reason = try c.decodeIfPresent(String.self, forKey:.reason) ?? ""; imageId = try c.decodeIfPresent(String.self, forKey:.imageId); regime = try c.decodeIfPresent(String.self, forKey:.regime); rMultiple = try c.decodeIfPresent(Double.self, forKey:.rMultiple)
    }
    init(id:Int,ticket:Int64,symbol:String,side:String,strategy:String,openedAt:Double,closedAt:Double,entry:Double,exit:Double,sl:Double,tp:Double,volume:Double,pnl:Double,result:String,reason:String,imageId:String?=nil,regime:String?=nil,rMultiple:Double?=nil) {
        self.id=id;self.ticket=ticket;self.symbol=symbol;self.side=side;self.strategy=strategy;self.openedAt=openedAt;self.closedAt=closedAt;self.entry=entry;self.exit=exit;self.sl=sl;self.tp=tp;self.volume=volume;self.pnl=pnl;self.result=result;self.reason=reason;self.imageId=imageId;self.regime=regime;self.rMultiple=rMultiple
    }
}

struct TradingSettings: Codable, Equatable, Sendable {
    var symbols:[String]; var riskPct:Double; var maxPositions:Int; var maxConsecutiveLosses:Int; var dailyLossLimitPct:Double; var sessionProfitLimit:Double; var realTradingEnabled:Bool
    var rr:Double; var slPoints:Double; var tpPoints:Double; var minConfidence:Double; var protectionPct:Double; var trailingTriggerPct:Double; var trailingGapPct:Double

    private enum CodingKeys:String,CodingKey { case symbols,riskPct,maxPositions,maxConsecutiveLosses,dailyLossLimitPct,sessionProfitLimit,realTradingEnabled,rr,slPoints,tpPoints,minConfidence,protectionPct,trailingTriggerPct,trailingGapPct }
    init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        symbols=try c.decodeIfPresent([String].self,forKey:.symbols) ?? []
        riskPct=try c.decodeIfPresent(Double.self,forKey:.riskPct) ?? 0.25
        maxPositions=try c.decodeIfPresent(Int.self,forKey:.maxPositions) ?? 1
        maxConsecutiveLosses=try c.decodeIfPresent(Int.self,forKey:.maxConsecutiveLosses) ?? 3
        dailyLossLimitPct=try c.decodeIfPresent(Double.self,forKey:.dailyLossLimitPct) ?? 0
        sessionProfitLimit=try c.decodeIfPresent(Double.self,forKey:.sessionProfitLimit) ?? 0
        realTradingEnabled=try c.decodeIfPresent(Bool.self,forKey:.realTradingEnabled) ?? false
        rr=try c.decodeIfPresent(Double.self,forKey:.rr) ?? 0; slPoints=try c.decodeIfPresent(Double.self,forKey:.slPoints) ?? 0; tpPoints=try c.decodeIfPresent(Double.self,forKey:.tpPoints) ?? 0
        minConfidence=try c.decodeIfPresent(Double.self,forKey:.minConfidence) ?? 0; protectionPct=try c.decodeIfPresent(Double.self,forKey:.protectionPct) ?? 0; trailingTriggerPct=try c.decodeIfPresent(Double.self,forKey:.trailingTriggerPct) ?? 0; trailingGapPct=try c.decodeIfPresent(Double.self,forKey:.trailingGapPct) ?? 0
    }
    init(symbols:[String],riskPct:Double,maxPositions:Int,maxConsecutiveLosses:Int,dailyLossLimitPct:Double,sessionProfitLimit:Double=0,realTradingEnabled:Bool=false,rr:Double=0,slPoints:Double=0,tpPoints:Double=0,minConfidence:Double=0,protectionPct:Double=0,trailingTriggerPct:Double=0,trailingGapPct:Double=0) {
        self.symbols=symbols;self.riskPct=riskPct;self.maxPositions=maxPositions;self.maxConsecutiveLosses=maxConsecutiveLosses;self.dailyLossLimitPct=dailyLossLimitPct;self.sessionProfitLimit=sessionProfitLimit;self.realTradingEnabled=realTradingEnabled;self.rr=rr;self.slPoints=slPoints;self.tpPoints=tpPoints;self.minConfidence=minConfidence;self.protectionPct=protectionPct;self.trailingTriggerPct=trailingTriggerPct;self.trailingGapPct=trailingGapPct
    }
    static let defaults = TradingSettings(symbols:["EURUSD"],riskPct:0.25,maxPositions:1,maxConsecutiveLosses:3,dailyLossLimitPct:2)
}

struct ReadinessSnapshot: Codable, Equatable, Sendable {
    let connected:Bool; let tradeAllowed:Bool; let accountTradeAllowed:Bool; let tradeExpert:Bool
    var ready:Bool { connected && tradeAllowed && accountTradeAllowed && tradeExpert }
}
struct AccountGuardSnapshot: Codable, Equatable, Sendable { let blocked:Bool; let reason:String?; let dailyPnl:Double?; let drawdownPct:Double?; let consecutiveLosses:Int? }
struct StrategyStat: Codable, Equatable, Identifiable, Sendable { let strategy:String; let symbol:String?; let regime:String?; let trades:Int?; let winRate:Double?; let profitFactor:Double?; let expectancyR:Double?; let enabled:Bool?; var id:String{[strategy,symbol ?? "",regime ?? ""].joined(separator:"|")} }

struct AnalysisSnapshot: Codable, Equatable, Identifiable, Sendable {
    let symbol:String; let regime:String; let state:String; let side:String?; let strategy:String?; let confidence:Double?; let reason:String?; let updatedAt:Double
    let direction:String?; let strength:Double?; let reasonCode:String?; let evaluatedCount:Int?
    var id:String{symbol}
    private enum CodingKeys:String,CodingKey{case symbol,regime,state,side,strategy,confidence,reason,updatedAt,direction,strength,reasonCode,evaluatedCount}
    init(from decoder:Decoder)throws{
        let c=try decoder.container(keyedBy:CodingKeys.self)
        symbol=try c.decode(String.self,forKey:.symbol); regime=try c.decodeIfPresent(String.self,forKey:.regime) ?? "UNKNOWN"; state=try c.decodeIfPresent(String.self,forKey:.state) ?? "WAIT"; side=try c.decodeIfPresent(String.self,forKey:.side); strategy=try c.decodeIfPresent(String.self,forKey:.strategy); confidence=try c.decodeIfPresent(Double.self,forKey:.confidence); reason=try c.decodeIfPresent(String.self,forKey:.reason); updatedAt=try c.decodeIfPresent(Double.self,forKey:.updatedAt) ?? 0; direction=try c.decodeIfPresent(String.self,forKey:.direction); strength=try c.decodeIfPresent(Double.self,forKey:.strength); reasonCode=try c.decodeIfPresent(String.self,forKey:.reasonCode); evaluatedCount=try c.decodeIfPresent(Int.self,forKey:.evaluatedCount)
    }
    init(symbol:String,regime:String,state:String,side:String?,strategy:String?,confidence:Double?,reason:String?,updatedAt:Double,direction:String?=nil,strength:Double?=nil,reasonCode:String?=nil,evaluatedCount:Int?=nil){
        self.symbol=symbol;self.regime=regime;self.state=state;self.side=side;self.strategy=strategy;self.confidence=confidence;self.reason=reason;self.updatedAt=updatedAt;self.direction=direction;self.strength=strength;self.reasonCode=reasonCode;self.evaluatedCount=evaluatedCount
    }
}

struct CommandResponse: Codable, Equatable, Sendable { let ok:Bool; let message:String }
struct LoginRequest: Codable, Sendable { let server:String; let login:Int64; let password:String }
struct LoginResponse: Codable, Equatable, Sendable { let ok:Bool; let message:String; let account:AccountSnapshot? }
struct TradingSettingsPatch: Codable, Sendable {
    let riskPct:Double;let maxPositions:Int;let maxConsecutiveLosses:Int;let dailyLossLimitPct:Double;let sessionProfitLimit:Double;let realTradingEnabled:Bool
    let rr:Double;let slPoints:Double;let tpPoints:Double;let minConfidence:Double;let protectionPct:Double;let trailingTriggerPct:Double;let trailingGapPct:Double
    init(_ v:TradingSettings){riskPct=v.riskPct;maxPositions=v.maxPositions;maxConsecutiveLosses=v.maxConsecutiveLosses;dailyLossLimitPct=v.dailyLossLimitPct;sessionProfitLimit=v.sessionProfitLimit;realTradingEnabled=v.realTradingEnabled;rr=v.rr;slPoints=v.slPoints;tpPoints=v.tpPoints;minConfidence=v.minConfidence;protectionPct=v.protectionPct;trailingTriggerPct=v.trailingTriggerPct;trailingGapPct=v.trailingGapPct}
}
struct SymbolsUpdateRequest: Codable, Sendable { let symbols:[String] }
struct SymbolsResponse: Codable, Equatable, Sendable { let selected:[String];let active:[String]?;let available:[String];let total:Int?;let hasMore:Bool? }
struct AuditEntry: Codable, Equatable, Identifiable, Sendable { let id:Int;let ts:Double;let event:String;let symbol:String;let details:[String:JSONValue];var displayID:Int{id} }

enum JSONValue: Codable, Equatable, Sendable {
    case string(String),number(Double),bool(Bool),object([String:JSONValue]),array([JSONValue]),null
    init(from decoder:Decoder)throws{let c=try decoder.singleValueContainer();if c.decodeNil(){self = .null}else if let v=try? c.decode(Bool.self){self = .bool(v)}else if let v=try? c.decode(Double.self){self = .number(v)}else if let v=try? c.decode(String.self){self = .string(v)}else if let v=try? c.decode([String:JSONValue].self){self = .object(v)}else if let v=try? c.decode([JSONValue].self){self = .array(v)}else{throw DecodingError.dataCorruptedError(in:c,debugDescription:"Unsupported JSON value")}}
    func encode(to encoder:Encoder)throws{var c=encoder.singleValueContainer();switch self{case .string(let v):try c.encode(v);case .number(let v):try c.encode(v);case .bool(let v):try c.encode(v);case .object(let v):try c.encode(v);case .array(let v):try c.encode(v);case .null:try c.encodeNil()}}
}
