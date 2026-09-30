import XCTest
@testable import T4Bot

final class APIModelTests: XCTestCase {
    func testLegacySnapshotStillDecodes() throws {
        let json = """
        {
          "server_time": 1790230000,
          "engine": {
            "running": true,
            "scan_count": 42,
            "last_cycle_seconds": 0.21,
            "last_cycle_at": 1790230000,
            "tracked_positions": 1,
            "max_positions": 3
          },
          "account": {
            "login": 113110182,
            "server": "MetaQuotes-Demo",
            "currency": "USD",
            "balance": 10000,
            "equity": 10010,
            "margin": 50,
            "margin_free": 9960,
            "profit": 10,
            "is_demo": true
          },
          "positions": [],
          "settings": {
            "symbols": ["EURUSD"],
            "risk_pct": 0.25,
            "rr": 3,
            "sl_points": 0,
            "tp_points": 0,
            "min_confidence": 75,
            "protection_pct": 45,
            "trailing_trigger_pct": 70,
            "trailing_gap_pct": 5,
            "max_positions": 3,
            "max_consecutive_losses": 3,
            "daily_loss_limit_pct": 2
          },
          "analysis": [],
          "readiness": {
            "connected": true,
            "trade_allowed": true,
            "account_trade_allowed": true,
            "trade_expert": true
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let snapshot = try decoder.decode(ServerSnapshot.self, from: json)

        XCTAssertTrue(snapshot.engine.running)
        XCTAssertEqual(snapshot.account?.login, 113110182)
        XCTAssertEqual(snapshot.settings.symbols, ["EURUSD"])
        XCTAssertNil(snapshot.accountGuard)
        XCTAssertNil(snapshot.strategyStats)
        XCTAssertTrue(snapshot.readiness.ready)
    }

    func testNewArchitectureFieldsDecode() throws {
        let json = """
        {
          "server_time": 1790230000,
          "engine": {
            "running": true,
            "scan_count": 500,
            "last_cycle_seconds": 0.27,
            "last_cycle_at": 1790230000,
            "tracked_positions": 0,
            "max_positions": 3,
            "selected_strategy": "liquidity_sweep_reclaim",
            "current_regime": "VOLATILE",
            "last_decision": "SIGNAL"
          },
          "positions": [],
          "settings": {"symbols":["EURUSD"],"risk_pct":10,"max_positions":3,"max_consecutive_losses":3,"daily_loss_limit_pct":5},
          "analysis": [{
            "symbol":"EURUSD","regime":"VOLATILE","state":"SIGNAL","side":"SELL",
            "strategy":"liquidity_sweep_reclaim","confidence":69,"reason":"SETUP_COMPLETE",
            "updated_at":1790230000,"direction":"DOWN","strength":0.6,"reason_code":"SETUP_COMPLETE","evaluated_count":25
          }],
          "readiness":{"connected":true,"trade_allowed":true,"account_trade_allowed":true,"trade_expert":true},
          "account_guard":{"blocked":false,"daily_pnl":0,"drawdown_pct":0.2,"consecutive_losses":0},
          "strategy_stats":[{"strategy":"liquidity_sweep_reclaim","symbol":"EURUSD","regime":"VOLATILE","trades":20,"win_rate":55,"profit_factor":1.2,"expectancy_r":0.1,"enabled":true}]
        }
        """.data(using:.utf8)!

        let decoder=JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let snapshot=try decoder.decode(ServerSnapshot.self,from:json)
        XCTAssertEqual(snapshot.engine.currentRegime,"VOLATILE")
        XCTAssertEqual(snapshot.analysis.first?.reasonCode,"SETUP_COMPLETE")
        XCTAssertEqual(snapshot.strategyStats?.first?.profitFactor,1.2)
    }

    func testConfigurationRequiresToken() {
        XCTAssertNotNil(APIConfiguration(token: "token"))
        XCTAssertNil(APIConfiguration(token: ""))
        XCTAssertNil(APIConfiguration(token: "   "))
    }
}
