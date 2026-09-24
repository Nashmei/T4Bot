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
    @Published private(set) var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @Published private(set) var deviceToken: String?
    @Published private(set) var lastRegistrationError: String?

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
        Task {
            await refreshAuthorizationStatus()
            liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        }
    }

    var pushStatusText: String {
        if let deviceToken, !deviceToken.isEmpty {
            return "مسجل"
        }
        if lastRegistrationError != nil {
            return "فشل التسجيل"
        }
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "بانتظار APNs"
        case .denied:
            return "مرفوض"
        case .notDetermined:
            return "غير مفعّل"
        @unknown default:
            return "غير معروف"
        }
    }

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            lastRegistrationError = error.localizedDescription
        }

        await refreshAuthorizationStatus()
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

        if authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func didRegisterForRemoteNotifications(token: String) {
        deviceToken = token
        lastRegistrationError = nil
        NotificationCenter.default.post(name: .t4botDeviceToken, object: token)
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        deviceToken = nil
        lastRegistrationError = error.localizedDescription
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
            _ = await presentLiveActivity(
                title: title,
                message: text,
                symbol: symbol,
                status: pnl == nil ? "live" : (pnl! >= 0 ? "profit" : "loss"),
                pnl: pnl,
                account: account
            )
        }
    }

    func testLiveActivity(account: AccountSnapshot?) async -> String {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivitiesEnabled else {
            return "Live Activities غير مفعّلة من إعدادات iOS."
        }

        let result = await presentLiveActivity(
            title: "T4Bot • اختبار",
            message: "الجزيرة التفاعلية تعمل وجاهزة لتنبيهات الصفقات.",
            symbol: "T4",
            status: "live",
            pnl: nil,
            account: account
        )

        return result ? "تم إرسال اختبار للجزيرة التفاعلية." : "تعذر تشغيل Live Activity."
    }

    func testLocalNotification() async -> String {
        await requestAuthorization()

        guard authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral else {
            return "صلاحية إشعارات iOS غير مفعّلة."
        }

        let content = UNMutableNotificationContent()
        content.title = "T4Bot • اختبار"
        content.body = "إشعارات iOS تعمل على هذا الجهاز."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "t4bot.local-test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return "تم إرسال إشعار اختبار. سيظهر خلال ثانية."
        } catch {
            return "فشل اختبار الإشعار: \(error.localizedDescription)"
        }
    }

    private func presentLiveActivity(
        title: String,
        message: String,
        symbol: String,
        status: String,
        pnl: Double?,
        account: AccountSnapshot?
    ) async -> Bool {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivitiesEnabled else { return false }

        let state = T4BotActivityAttributes.ContentState(
            title: title,
            message: message,
            symbol: symbol,
            status: status,
            pnl: pnl
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(180),
            relevanceScore: status == "profit" || status == "loss" ? 100 : 80
        )

        if let activity {
            await activity.update(content)
            return true
        }

        let attributes = T4BotActivityAttributes(
            accountLabel: account.map { "\($0.login)" } ?? "Mtbot"
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            return activity != nil
        } catch {
            return false
        }
    }

    func endLiveActivity() async {
        guard let activity else { return }

        let state = T4BotActivityAttributes.ContentState(
            title: "T4Bot",
            message: "انتهى الاتصال المباشر.",
            symbol: "",
            status: "idle",
            pnl: nil
        )

        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(8))
        )
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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    private enum EventCategory {
        case tradeOpened
        case tradeClosed
        case protection
        case engine
        case connection
    }

    private func category(for text: String, pnl: Double?) -> EventCategory {
        if pnl != nil || text.contains("النتيجة") || text.contains("TP") || text.contains("SL") {
            return .tradeClosed
        }
        if text.contains("حماية") {
            return .protection
        }
        if text.contains("اتصال") || text.contains("MT5") {
            return .connection
        }
        if text.contains("تنفيذ") || text.contains("صفقة") {
            return .tradeOpened
        }
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
        if text.contains("النتيجة") || text.contains("ربح") || text.contains("خسارة") {
            return "نتيجة الصفقة"
        }
        if text.contains("تنفيذ") || text.contains("OPEN") || text.contains("صفقة") {
            return "T4Bot • صفقة"
        }
        if text.contains("توقف") || text.contains("خطأ") || text.contains("🚨") {
            return "تنبيه T4Bot"
        }
        return "T4Bot"
    }

    private func detectSymbol(_ text: String) -> String {
        let uppercase = text.uppercased()
        let separators = CharacterSet.alphanumerics.inverted
        let candidates = uppercase.components(separatedBy: separators)

        let ignored: Set<String> = ["T4BOT", "MT5", "DEMO", "BUY", "SELL", "OPEN", "SL", "TP"]

        return candidates.first { value in
            !ignored.contains(value)
            && value.count >= 6
            && value.count <= 14
            && value.unicodeScalars.allSatisfy { CharacterSet.uppercaseLetters.contains($0) }
        } ?? ""
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            NotificationManager.shared.didRegisterForRemoteNotifications(token: token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        guard case .string(let value)? = self[key] else { return nil }
        return value
    }

    func double(_ key: String) -> Double? {
        switch self[key] {
        case .number(let value)?:
            return value
        case .string(let value)?:
            return Double(value)
        default:
            return nil
        }
    }
}
