import ActivityKit
import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

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

    private var activity: Activity<T4BotActivityAttributes>?
    private var activityDismissTask: Task<Void, Never>?

    override init() {
        inAppEnabled = UserDefaults.standard.object(forKey: "notifications.inApp") as? Bool ?? true
        outsideEnabled = UserDefaults.standard.object(forKey: "notifications.outside") as? Bool ?? true
        tradeOpened = UserDefaults.standard.object(forKey: "notifications.tradeOpened") as? Bool ?? true
        tradeClosed = UserDefaults.standard.object(forKey: "notifications.tradeClosed") as? Bool ?? true
        profitProtection = UserDefaults.standard.object(forKey: "notifications.profitProtection") as? Bool ?? true
        super.init()

        UNUserNotificationCenter.current().delegate = self

        Task { [weak self] in
            guard let self else { return }
            await self.refreshAuthorizationStatus()
            self.liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
            await self.clearStaleLiveActivities()
        }
    }

    var authorizationStatusText: String {
        switch authorizationStatus {
        case .authorized:
            return "مفعّلة"
        case .provisional:
            return "مفعّلة مؤقتاً"
        case .ephemeral:
            return "مفعّلة مؤقتاً"
        case .denied:
            return "مرفوضة"
        case .notDetermined:
            return "لم تُطلب بعد"
        @unknown default:
            return "غير معروف"
        }
    }

    var authorizationGranted: Bool {
        authorizationStatus == .authorized
        || authorizationStatus == .provisional
        || authorizationStatus == .ephemeral
    }

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            // The status row below remains the source of truth for the user.
        }

        await refreshAuthorizationStatus()
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func handle(event: RealtimeEvent, account: AccountSnapshot?) async {
        guard let kind = TradeEventKind(rawValue: event.type) else { return }
        guard categoryEnabled(kind) else { return }

        let alert = makeAlert(kind: kind, event: event)

        if outsideEnabled {
            await scheduleLocalNotification(alert)
        }

        if inAppEnabled {
            _ = await presentLiveActivity(alert: alert, account: account)
        }
    }

    func testLiveActivity(account: AccountSnapshot?) async -> String {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivitiesEnabled else {
            return "Live Activities غير مفعّلة من إعدادات iOS."
        }

        let alert = TradeAlert(
            kind: .tradeOpened,
            title: "T4Bot • اختبار",
            message: "الجزيرة التفاعلية تعمل وستختفي تلقائياً.",
            symbol: "T4",
            pnl: nil,
            ticket: nil
        )

        let result = await presentLiveActivity(alert: alert, account: account)
        return result ? "تم تشغيل اختبار الجزيرة التفاعلية." : "تعذر تشغيل Live Activity."
    }

    func testLocalNotification() async -> String {
        await requestAuthorization()

        guard authorizationGranted else {
            return "صلاحية إشعارات iOS غير مفعّلة."
        }

        let content = UNMutableNotificationContent()
        content.title = "T4Bot • اختبار"
        content.body = "الإشعار المحلي يعمل على هذا الجهاز."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "t4bot.local-test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return "تم إرسال إشعار محلي. سيظهر خلال ثانية."
        } catch {
            return "فشل اختبار الإشعار: \(error.localizedDescription)"
        }
    }

    func endLiveActivity() async {
        activityDismissTask?.cancel()
        activityDismissTask = nil

        guard let active = activity else { return }
        await end(active, dismissalPolicy: .immediate)
        activity = nil
    }

    private func clearStaleLiveActivities() async {
        activityDismissTask?.cancel()
        activityDismissTask = nil

        for active in Activity<T4BotActivityAttributes>.activities {
            await end(active, dismissalPolicy: .immediate)
        }

        activity = nil
    }

    private func end(
        _ active: Activity<T4BotActivityAttributes>,
        dismissalPolicy: ActivityUIDismissalPolicy
    ) async {
        let idle = T4BotActivityAttributes.ContentState(
            title: "T4Bot",
            message: "",
            symbol: "",
            status: "idle",
            pnl: nil
        )

        await active.end(
            ActivityContent(state: idle, staleDate: nil),
            dismissalPolicy: dismissalPolicy
        )
    }

    private func scheduleLocalNotification(_ alert: TradeAlert) async {
        await refreshAuthorizationStatus()
        guard authorizationGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        content.sound = .default

        if let ticket = alert.ticket {
            content.threadIdentifier = "trade-\(ticket)"
        } else {
            content.threadIdentifier = "t4bot-trades"
        }

        let ticketID = alert.ticket.map { String($0) } ?? UUID().uuidString
        let request = UNNotificationRequest(
            identifier: "t4bot.\(alert.kind.rawValue).\(ticketID).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func presentLiveActivity(
        alert: TradeAlert,
        account: AccountSnapshot?
    ) async -> Bool {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivitiesEnabled else { return false }

        let status: String
        switch alert.kind {
        case .tradeOpened:
            status = "live"
        case .tradeClosed:
            if let pnl = alert.pnl {
                status = pnl >= 0 ? "profit" : "loss"
            } else {
                status = "closed"
            }
        case .profitProtection:
            status = "protected"
        }

        let state = T4BotActivityAttributes.ContentState(
            title: alert.title,
            message: alert.message,
            symbol: alert.symbol,
            status: status,
            pnl: alert.pnl
        )

        let relevanceScore: Double
        switch alert.kind {
        case .tradeClosed:
            relevanceScore = 100
        case .tradeOpened, .profitProtection:
            relevanceScore = 90
        }

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(15),
            relevanceScore: relevanceScore
        )

        if let active = activity {
            await active.update(content)
        } else {
            let attributes = T4BotActivityAttributes(
                accountLabel: account.map { "\($0.login)" } ?? "Mtbot"
            )

            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                return false
            }
        }

        scheduleLiveActivityDismissal()
        return activity != nil
    }

    private func scheduleLiveActivityDismissal() {
        activityDismissTask?.cancel()
        activityDismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return
            }

            guard !Task.isCancelled, let self else { return }
            await self.endLiveActivity()
        }
    }

    private func makeAlert(kind: TradeEventKind, event: RealtimeEvent) -> TradeAlert {
        let symbol = event.payload.string("symbol") ?? detectSymbol(event.payload.string("text") ?? "")
        let side = localizedSide(event.payload.string("side"))
        let ticket = event.payload.int64("trade_ticket")
        let pnl = event.payload.double("trade_result")
        let reason = event.payload.string("trade_result_reason")
        let originalText = event.payload.string("text") ?? ""

        switch kind {
        case .tradeOpened:
            var details = [symbol, side].filter { !$0.isEmpty }
            if let ticket {
                details.append("#\(ticket)")
            }

            return TradeAlert(
                kind: kind,
                title: "T4Bot • تم فتح صفقة",
                message: details.isEmpty ? concise(originalText) : details.joined(separator: " • "),
                symbol: symbol,
                pnl: nil,
                ticket: ticket
            )

        case .tradeClosed:
            var details: [String] = []
            if !symbol.isEmpty {
                details.append(symbol)
            }
            if let pnl {
                details.append(String(format: "%+.2f", pnl))
            }
            if let reason, !reason.isEmpty {
                details.append(reason)
            }
            if let ticket {
                details.append("#\(ticket)")
            }

            let title: String
            if let pnl {
                title = pnl > 0 ? "T4Bot • صفقة رابحة" : (pnl < 0 ? "T4Bot • صفقة خاسرة" : "T4Bot • إغلاق الصفقة")
            } else {
                title = "T4Bot • إغلاق الصفقة"
            }

            return TradeAlert(
                kind: kind,
                title: title,
                message: details.isEmpty ? concise(originalText) : details.joined(separator: " • "),
                symbol: symbol,
                pnl: pnl,
                ticket: ticket
            )

        case .profitProtection:
            var details = [symbol].filter { !$0.isEmpty }
            if let ticket {
                details.append("#\(ticket)")
            }

            return TradeAlert(
                kind: kind,
                title: "T4Bot • حماية الربح",
                message: details.isEmpty ? "تم تفعيل حماية الربح." : "تم تفعيل الحماية • " + details.joined(separator: " • "),
                symbol: symbol,
                pnl: nil,
                ticket: ticket
            )
        }
    }

    private func categoryEnabled(_ kind: TradeEventKind) -> Bool {
        switch kind {
        case .tradeOpened:
            return tradeOpened
        case .tradeClosed:
            return tradeClosed
        case .profitProtection:
            return profitProtection
        }
    }

    private func localizedSide(_ side: String?) -> String {
        switch side?.uppercased() {
        case "BUY":
            return "شراء"
        case "SELL":
            return "بيع"
        default:
            return ""
        }
    }

    private func concise(_ text: String) -> String {
        let oneLine = text
            .replacingOccurrences(of: "\n", with: " • ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if oneLine.count <= 140 {
            return oneLine.isEmpty ? "تحديث صفقة من Mtbot" : oneLine
        }

        return String(oneLine.prefix(137)) + "..."
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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

private enum TradeEventKind: String {
    case tradeOpened = "trade_opened"
    case tradeClosed = "trade_closed"
    case profitProtection = "profit_protection"
}

private struct TradeAlert {
    let kind: TradeEventKind
    let title: String
    let message: String
    let symbol: String
    let pnl: Double?
    let ticket: Int64?
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

    func int64(_ key: String) -> Int64? {
        switch self[key] {
        case .number(let value)?:
            return Int64(value)
        case .string(let value)?:
            return Int64(value)
        default:
            return nil
        }
    }
}
