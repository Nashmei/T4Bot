import XCTest
@testable import T4Bot

final class APIModelTests: XCTestCase {
    func testSnapshotDecodesSnakeCaseContract() throws {
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
            "min_confidence": 75,
            "protection_pct": 45,
            "max_trade_minutes": 10,
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
        XCTAssertTrue(snapshot.readiness.ready)
    }

    func testConfigurationRequiresHTTPS() {
        XCTAssertNil(APIConfiguration(baseURLString: "http://example.com", token: "token"))
        XCTAssertNotNil(APIConfiguration(baseURLString: "https://example.com", token: "token"))
        XCTAssertNil(APIConfiguration(baseURLString: "https://example.com", token: ""))
    }
}
