import Foundation

#if DEBUG
enum PreviewData {
    static let snapshot = ServerSnapshot(
        serverTime: Date().timeIntervalSince1970,
        engine: .init(
            running: true, scanCount: 842, lastCycleSeconds: 0.31,
            lastCycleAt: Date().timeIntervalSince1970, trackedPositions: 2, maxPositions: 6,
            selectedStrategy: "liquidity_sweep_reclaim", currentRegime: "VOLATILE", lastDecision: "WAIT"
        ),
        account: .init(login: 113180443, server: "MetaQuotes-Demo", currency: "USD", balance: 4943.26, equity: 5018.40, margin: 530.0, marginFree: 4488.4, profit: 75.14, isDemo: true),
        positions: [
            .init(ticket: 10689350715, symbol: "XAUUSD", side: "BUY", volume: 0.39, priceOpen: 4294.08, priceCurrent: 4296.12, sl: 4291.50, tp: 4298.50, profit: 31.80, magic: 1, strategy: "gold_momentum_scalp", regime: "TREND", riskCash: 50, riskPct: 1),
            .init(ticket: 10689350716, symbol: "EURUSD", side: "SELL", volume: 0.22, priceOpen: 1.1742, priceCurrent: 1.1736, sl: 1.1760, tp: 1.1701, profit: 43.34, magic: 1, strategy: "liquidity_sweep_reclaim", regime: "VOLATILE", riskCash: 35, riskPct: 0.7)
        ],
        settings: .init(symbols:["XAUUSD","EURUSD","GBPUSD"], riskPct:2, maxPositions:6, maxConsecutiveLosses:3, dailyLossLimitPct:4),
        analysis: [
            .init(symbol:"XAUUSD",regime:"TREND",state:"WAIT",side:nil,strategy:"gold_trend_pullback",confidence:71,reason:"WAIT_PULLBACK",updatedAt:Date().timeIntervalSince1970,direction:"UP",strength:0.72,reasonCode:"WAIT_PULLBACK",evaluatedCount:25),
            .init(symbol:"EURUSD",regime:"VOLATILE",state:"SIGNAL",side:"SELL",strategy:"liquidity_sweep_reclaim",confidence:69,reason:"SETUP_COMPLETE",updatedAt:Date().timeIntervalSince1970,direction:"DOWN",strength:0.61,reasonCode:"SETUP_COMPLETE",evaluatedCount:25)
        ],
        readiness: .init(connected:true,tradeAllowed:true,accountTradeAllowed:true,tradeExpert:true),
        accountGuard: .init(blocked:false,reason:nil,dailyPnl:42.5,drawdownPct:0.8,consecutiveLosses:0),
        strategyStats: []
    )

    static let history:[ClosedTrade] = [
        .init(id:1,ticket:106800001,symbol:"XAUUSD",side:"BUY",strategy:"gold_momentum_scalp",openedAt:1,closedAt:2,entry:4290,exit:4297,sl:4287,tp:4297,volume:0.2,pnl:84.2,result:"WIN",reason:"TP",regime:"TREND",rMultiple:1.8),
        .init(id:2,ticket:106800002,symbol:"GBPUSD",side:"SELL",strategy:"trend_momentum_resume",openedAt:1,closedAt:2,entry:1.348,exit:1.350,sl:1.350,tp:1.344,volume:0.3,pnl:-42.6,result:"LOSS",reason:"SL",regime:"TREND",rMultiple:-1)
    ]
}
#endif
