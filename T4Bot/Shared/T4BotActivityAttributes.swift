import ActivityKit
import Foundation

struct T4BotActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var message: String
        var symbol: String
        var status: String
        var pnl: Double?
    }

    var accountLabel: String
}
