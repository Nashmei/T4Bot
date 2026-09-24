import ActivityKit
import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let t4botDeviceToken = Notification.Name("t4botDeviceToken")
}

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var inAppEnabled: Bool {
        didSet { UserDefaults.standard.set(inAppEnabled, forKey: "notifications.inApp") }
    }
    @Published var outsideEnabled: Bool {
        didSet { UserDefaults.standard.set(outsideEnabled, forKey: "notifications.outside") }
    }
    @Published var tradeOpened: Bool {
        didSet { UserDefaults.standard.set(tradeOpened, forKey: "notifications.tradeOpened") }
    }
    @Published var tradeClosed: Bool {
        didSet { UserDefaults.standard.set(tradeClosed, forKey: "notifications.tradeClosed") }
    }
    @Published var profitProtection: Bool {
        didSet { UserDefaults.standard.set(profitProtection, forKey: "notifications.profitProtection") }
    }
    @Published var engineAlerts: Bool {
        didSet { UserDefaults.standard.set(engineAlerts, forKey: "notifications.engineAlerts") }
    }
    @Published var connectionAlerts: Bool {
        didSet { UserDefaults.standard.set(connectionAlerts, forKey: "notifications.connectionAlerts") }
    }

    private var activity: Activity<T4BotActivityAttributes>?

    override init() {
        inAppEnabled = UserDefaults.standard.object(forKey: "notifications.inApp") as? Bool ?? true
        outsideEnabled = UserDefaults.standard.object(forKey: "notifications.outside") as? Bool ?? true
        tradeOpened = UserDefaults.standard.object(forKey: "notifications.tradeOpened") as? Bool ?? true
        tradeClosed = UserDefaults.standard.object(forKey: "notifications.tradeClosed") as? Bool ?? true
        profitProtection = UserDefaults.standard.object(forKey: "notifications.profitProtection") as? Bool ?? true
        engineAlerts = UserDefaults.standard.object(forKey: "notifications.engineAlerts") as? Bool ?? true
        connectionAlerts = UserDefaults.standard.object(forKey: "notifications.connectionAlerts") as? Bool ?? true
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthorizationStatus() }
    }

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if authorizationStatus == .authorized || authorizationStatus == .provisional {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            await refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func handle(event: RealtimeEvent, account: AccountSnapshot?) async {
        guard event.type == "engine_notification" else { return }

        let text = event.payload.string("text") ?? "تحديث من Mtbot"
        let title = eventTitle(text)
        let symbol = detectSymbol(text)
        let pnl = event.payload.double("trade_result")
        let category = category(for: text, pnl: pnl)
        guard categoryEnabled(category) else { return }

        if inAppEnabled {
            await updateLiveActivity(
                title: title,
                message: text,
                symbol: symbol,
                status: pnl == nil ? "live" : (pnl! >= 0 ? "profit" : "loss"),
                pnl: pnl,
                account: account
            )
        }

        if outsideEnabled, UIApplication.shared.applicationState != .active {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = text
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func updateLiveActivity(
        title: String,
        message: String,
        symbol: String,
        status: String,
        pnl: Double?,
        account: AccountSnapshot?
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = T4BotActivityAttributes.ContentState(
            title: title,
            message: message,
            symbol: symbol,
            status: status,
            pnl: pnl
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))

        if let activity {
            await activity.update(content)
            return
        }

        let attributes = T4BotActivityAttributes(
            accountLabel: account.map { "\($0.login)" } ?? "Mtbot"
        )
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    func endLiveActivity() async {
        guard let activity else { return }
        let state = T4BotActivityAttributes.ContentState(
            title: "T4Bot",
            message: "الاتصال متوقف",
            symbol: "",
            status: "idle",
            pnl: nil
        )
        await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        self.activity = nil
    }

    var serverPreferences: [String: Bool] {
        [
            "trade_opened": tradeOpened,
            "trade_closed": tradeClosed,
            "profit_protection": profitProtection,
            "engine_alerts": engineAlerts,
            "connection_alerts": connectionAlerts
        ]
    }

    private enum EventCategory {
        case tradeOpened, tradeClosed, protection, engine, connection
    }

    private func category(for text: String, pnl: Double?) -> EventCategory {
        if pnl != nil || text.contains("النتيجة") || text.contains("TP") || text.contains("SL") { return .tradeClosed }
        if text.contains("حماية") { return .protection }
        if text.contains("اتصال") || text.contains("MT5") { return .connection }
        if text.contains("تنفيذ") || text.contains("صفقة") { return .tradeOpened }
        return .engine
    }

    private func categoryEnabled(_ category: EventCategory) -> Bool {
        switch category {
        case .tradeOpened: return tradeOpened
        case .tradeClosed: return tradeClosed
        case .protection: return profitProtection
        case .engine: return engineAlerts
        case .connection: return connectionAlerts
        }
    }

    private func eventTitle(_ text: String) -> String {
        if text.contains("النتيجة") || text.contains("ربح") || text.contains("خسارة") { return "نتيجة الصفقة" }
        if text.contains("تنفيذ") || text.contains("OPEN") || text.contains("صفقة") { return "T4Bot • صفقة" }
        if text.contains("توقف") || text.contains("خطأ") || text.contains("🚨") { return "تنبيه T4Bot" }
        return "T4Bot"
    }

    private func detectSymbol(_ text: String) -> String {
        ["XAUUSD", "EURUSD", "GBPUSD", "AUDUSD", "USDJPY", "USDCAD"].first(where: { text.uppercased().contains($0) }) ?? ""
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .t4botDeviceToken, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Local notifications and Live Activities remain available.
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        guard case .string(let value)? = self[key] else { return nil }
        return value
    }

    func double(_ key: String) -> Double? {
        switch self[key] {
        case .number(let value)?: return value
        case .string(let value)?: return Double(value)
        default: return nil
        }
    }
}
