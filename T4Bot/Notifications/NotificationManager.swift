import ActivityKit
import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @Published private(set) var apnsDeviceToken = ""
    @Published private(set) var apnsRegistrationStatus = "لم يتم التسجيل"
    @Published private(set) var apnsLastError = ""

    @Published var inAppEnabled: Bool { didSet { UserDefaults.standard.set(inAppEnabled, forKey: "notifications.inApp") } }
    @Published var outsideEnabled: Bool { didSet { UserDefaults.standard.set(outsideEnabled, forKey: "notifications.outside") } }
    @Published var tradeOpened: Bool { didSet { UserDefaults.standard.set(tradeOpened, forKey: "notifications.tradeOpened") } }
    @Published var tradeClosed: Bool { didSet { UserDefaults.standard.set(tradeClosed, forKey: "notifications.tradeClosed") } }
    @Published var profitProtection: Bool { didSet { UserDefaults.standard.set(profitProtection, forKey: "notifications.profitProtection") } }

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
        case .authorized: return "مفعّلة"
        case .provisional, .ephemeral: return "مفعّلة مؤقتاً"
        case .denied: return "مرفوضة"
        case .notDetermined: return "لم تُطلب بعد"
        @unknown default: return "غير معروف"
        }
    }

    var authorizationGranted: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    var apnsEnvironment: String { embeddedProvisioningSummary()["aps-environment"] ?? "غير معروف" }

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            apnsLastError = error.localizedDescription
        }
        await refreshAuthorizationStatus()
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func registerForRemoteNotifications() async {
        await requestAuthorization()
        guard authorizationGranted else {
            apnsRegistrationStatus = "صلاحية الإشعارات غير مفعّلة"
            return
        }
        apnsLastError = ""
        apnsRegistrationStatus = "جاري التسجيل..."
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        apnsDeviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        apnsRegistrationStatus = "Registered"
        apnsLastError = ""
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        apnsRegistrationStatus = "Failed"
        apnsLastError = error.localizedDescription
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func embeddedProvisioningSummary() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let raw = String(data: data, encoding: .isoLatin1),
              let start = raw.range(of: "<?xml"),
              let end = raw.range(of: "</plist>", options: .backwards) else { return [:] }
        let xml = String(raw[start.lowerBound..<end.upperBound])
        guard let plistData = xml.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil),
              let root = plist as? [String: Any] else { return [:] }
        let ent = root["Entitlements"] as? [String: Any] ?? [:]
        var out: [String: String] = [:]
        out["profile-name"] = root["Name"] as? String
        out["profile-uuid"] = root["UUID"] as? String
        out["team-identifier"] = (root["TeamIdentifier"] as? [String])?.first
        out["application-identifier"] = ent["application-identifier"] as? String
        out["aps-environment"] = ent["aps-environment"] as? String
        if let exp = root["ExpirationDate"] as? Date { out["expiration"] = ISO8601DateFormatter().string(from: exp) }
        return out
    }

    func exportDiagnosticFiles() throws -> URL {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("T4Bot-APNs-Diagnostics", isDirectory: true)
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        if let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") {
            try fm.copyItem(at: profile, to: folder.appendingPathComponent("embedded.mobileprovision"))
        }
        if let info = Bundle.main.infoDictionary {
            let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try data.write(to: folder.appendingPathComponent("Info.plist"))
        }

        var report = embeddedProvisioningSummary()
        report["bundle-id"] = Bundle.main.bundleIdentifier ?? ""
        report["apns-device-token"] = apnsDeviceToken
        report["apns-registration"] = apnsRegistrationStatus
        report["apns-error"] = apnsLastError
        let reportText = report.keys.sorted().map { "\($0)=\(report[$0] ?? "")" }.joined(separator: "\n") + "\n"
        try Data(reportText.utf8).write(to: folder.appendingPathComponent("apns-diagnostics.txt"))
        return folder
    }

    func handle(event: RealtimeEvent, account: AccountSnapshot?) async {
        guard let kind = TradeEventKind(rawValue: event.type), categoryEnabled(kind) else { return }
        let alert = makeAlert(kind: kind, event: event)
        if outsideEnabled { await scheduleLocalNotification(alert) }
        if inAppEnabled { _ = await presentLiveActivity(alert: alert, account: account) }
    }

    func testLiveActivity(account: AccountSnapshot?) async -> String {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivitiesEnabled else { return "Live Activities غير مفعّلة من إعدادات iOS." }
        let alert = TradeAlert(kind: .tradeOpened, title: "T4Bot • اختبار", message: "الجزيرة التفاعلية تعمل وستختفي تلقائياً.", symbol: "T4", pnl: nil, ticket: nil)
        return await presentLiveActivity(alert: alert, account: account) ? "تم تشغيل اختبار الجزيرة التفاعلية." : "تعذر تشغيل Live Activity."
    }

    func testLocalNotification() async -> String {
        await requestAuthorization()
        guard authorizationGranted else { return "صلاحية إشعارات iOS غير مفعّلة." }
        let content = UNMutableNotificationContent()
        content.title = "T4Bot • اختبار"
        content.body = "الإشعار المحلي يعمل على هذا الجهاز."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "t4bot.local-test.\(UUID().uuidString)", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        do { try await UNUserNotificationCenter.current().add(request); return "تم إرسال إشعار محلي. سيظهر خلال ثانية." }
        catch { return "فشل اختبار الإشعار: \(error.localizedDescription)" }
    }

    func endLiveActivity() async {
        activityDismissTask?.cancel(); activityDismissTask = nil
        guard let active = activity else { return }
        await end(active, dismissalPolicy: .immediate); activity = nil
    }

    private func clearStaleLiveActivities() async {
        activityDismissTask?.cancel(); activityDismissTask = nil
        for active in Activity<T4BotActivityAttributes>.activities { await end(active, dismissalPolicy: .immediate) }
        activity = nil
    }

    private func end(_ active: Activity<T4BotActivityAttributes>, dismissalPolicy: ActivityUIDismissalPolicy) async {
        let idle = T4BotActivityAttributes.ContentState(title: "T4Bot", message: "", symbol: "", status: "idle", pnl: nil)
        await active.end(ActivityContent(state: idle, staleDate: nil), dismissalPolicy: dismissalPolicy)
    }

    private func scheduleLocalNotification(_ alert: TradeAlert) async {
        await refreshAuthorizationStatus(); guard authorizationGranted else { return }
        let content = UNMutableNotificationContent(); content.title = alert.title; content.body = alert.message; content.sound = .default
        content.threadIdentifier = alert.ticket.map { "trade-\($0)" } ?? "t4bot-trades"
        let ticketID = alert.ticket.map(String.init) ?? UUID().uuidString
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "t4bot.\(alert.kind.rawValue).\(ticketID).\(UUID().uuidString)", content: content, trigger: nil))
    }

    private func presentLiveActivity(alert: TradeAlert, account: AccountSnapshot?) async -> Bool {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled; guard liveActivitiesEnabled else { return false }
        let status: String
        switch alert.kind {
        case .tradeOpened: status = "live"
        case .tradeClosed: status = alert.pnl.map { $0 >= 0 ? "profit" : "loss" } ?? "closed"
        case .profitProtection: status = "protected"
        }
        let state = T4BotActivityAttributes.ContentState(title: alert.title, message: alert.message, symbol: alert.symbol, status: status, pnl: alert.pnl)
        let score: Double = alert.kind == .tradeClosed ? 100 : 90
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15), relevanceScore: score)
        if let active = activity { await active.update(content) }
        else {
            do { activity = try Activity.request(attributes: T4BotActivityAttributes(accountLabel: account.map { "\($0.login)" } ?? "Mtbot"), content: content, pushType: nil) }
            catch { return false }
        }
        scheduleLiveActivityDismissal(); return activity != nil
    }

    private func scheduleLiveActivityDismissal() {
        activityDismissTask?.cancel()
        activityDismissTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard !Task.isCancelled, let self else { return }; await self.endLiveActivity()
        }
    }

    private func makeAlert(kind: TradeEventKind, event: RealtimeEvent) -> TradeAlert {
        let symbol = event.payload.string("symbol") ?? detectSymbol(event.payload.string("text") ?? "")
        let side = localizedSide(event.payload.string("side")); let ticket = event.payload.int64("trade_ticket")
        let pnl = event.payload.double("trade_result"); let reason = event.payload.string("trade_result_reason"); let original = event.payload.string("text") ?? ""
        switch kind {
        case .tradeOpened:
            var d = [symbol, side].filter { !$0.isEmpty }; if let ticket { d.append("#\(ticket)") }
            return TradeAlert(kind: kind, title: "T4Bot • تم فتح صفقة", message: d.isEmpty ? concise(original) : d.joined(separator: " • "), symbol: symbol, pnl: nil, ticket: ticket)
        case .tradeClosed:
            var d = [String](); if !symbol.isEmpty { d.append(symbol) }; if let pnl { d.append(String(format: "%+.2f", pnl)) }; if let reason, !reason.isEmpty { d.append(reason) }; if let ticket { d.append("#\(ticket)") }
            let title = pnl.map { $0 > 0 ? "T4Bot • صفقة رابحة" : ($0 < 0 ? "T4Bot • صفقة خاسرة" : "T4Bot • إغلاق الصفقة") } ?? "T4Bot • إغلاق الصفقة"
            return TradeAlert(kind: kind, title: title, message: d.isEmpty ? concise(original) : d.joined(separator: " • "), symbol: symbol, pnl: pnl, ticket: ticket)
        case .profitProtection:
            var d = [symbol].filter { !$0.isEmpty }; if let ticket { d.append("#\(ticket)") }
            return TradeAlert(kind: kind, title: "T4Bot • حماية الربح", message: d.isEmpty ? "تم تفعيل حماية الربح." : "تم تفعيل الحماية • " + d.joined(separator: " • "), symbol: symbol, pnl: nil, ticket: ticket)
        }
    }

    private func categoryEnabled(_ kind: TradeEventKind) -> Bool { kind == .tradeOpened ? tradeOpened : (kind == .tradeClosed ? tradeClosed : profitProtection) }
    private func localizedSide(_ side: String?) -> String { side?.uppercased() == "BUY" ? "شراء" : (side?.uppercased() == "SELL" ? "بيع" : "") }
    private func concise(_ text: String) -> String { let s=text.replacingOccurrences(of:"\n",with:" • ").trimmingCharacters(in:.whitespacesAndNewlines); return s.count <= 140 ? (s.isEmpty ? "تحديث صفقة من Mtbot" : s) : String(s.prefix(137))+"..." }
    private func detectSymbol(_ text: String) -> String {
        let ignored:Set<String>=["T4BOT","MT5","DEMO","BUY","SELL","OPEN","SL","TP"]
        return text.uppercased().components(separatedBy:.alphanumerics.inverted).first { !ignored.contains($0) && $0.count >= 6 && $0.count <= 14 && $0.unicodeScalars.allSatisfy { CharacterSet.uppercaseLetters.contains($0) } } ?? ""
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)->Void) { completionHandler([.banner,.list,.sound]) }
}

private enum TradeEventKind:String { case tradeOpened="trade_opened", tradeClosed="trade_closed", profitProtection="profit_protection" }
private struct TradeAlert { let kind:TradeEventKind; let title:String; let message:String; let symbol:String; let pnl:Double?; let ticket:Int64? }
private extension Dictionary where Key==String, Value==JSONValue {
    func string(_ key:String)->String? { guard case .string(let v)?=self[key] else{return nil}; return v }
    func double(_ key:String)->Double? { switch self[key] { case .number(let v)?:return v; case .string(let v)?:return Double(v); default:return nil } }
    func int64(_ key:String)->Int64? { switch self[key] { case .number(let v)?:return Int64(v); case .string(let v)?:return Int64(v); default:return nil } }
}
