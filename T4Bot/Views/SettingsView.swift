import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            NavigationLink { AppearanceSettingsView() } label: { SettingsRoute(icon:"circle.lefthalf.filled", title:"المظهر", subtitle:"تلقائي، فاتح أو داكن") }
            NavigationLink { RiskSettingsView() } label: { SettingsRoute(icon:"shield.lefthalf.filled", title:"المخاطرة والحدود", subtitle:"المخاطرة، الثقة، حدود الجلسة والمراكز") }
            NavigationLink { TradeManagementSettingsView() } label: { SettingsRoute(icon:"brain.head.profile", title:"إدارة الصفقة", subtitle:"R:R و SL/TP والحماية والتتبع") }
            NavigationLink { NotificationSettingsView() } label: { SettingsRoute(icon:"bell.fill", title:"الإشعارات", subtitle:"صفقات، حماية الربح وهدف الجلسة") }
        }
        .listStyle(.insetGrouped)
        .t4ListBackground()
        .navigationTitle("الإعدادات")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsRoute: View {
    let icon:String; let title:String; let subtitle:String
    var body: some View {
        HStack(spacing:13) {
            Image(systemName:icon).font(.headline).foregroundStyle(T4Palette.accent).frame(width:38,height:38).background(T4Palette.accent.opacity(0.10),in:RoundedRectangle(cornerRadius:11,style:.continuous))
            VStack(alignment:.leading,spacing:3) { Text(title).font(.body.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical,5)
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance=AppAppearance.system.rawValue
    var body:some View {
        List {
            ForEach(AppAppearance.allCases) { option in
                Button { appearance=option.rawValue } label: {
                    HStack { Label(option.title,systemImage:icon(option)).foregroundStyle(.primary); Spacer(); if appearance == option.rawValue { Image(systemName:"checkmark.circle.fill").foregroundStyle(T4Palette.accent) } }
                }
            }
        }.listStyle(.insetGrouped).t4ListBackground().navigationTitle("المظهر").navigationBarTitleDisplayMode(.inline)
    }
    private func icon(_ option:AppAppearance)->String { switch option { case .system:return "iphone"; case .dark:return "moon.fill"; case .light:return "sun.max.fill" } }
}

private struct RiskSettingsView: View {
    @EnvironmentObject private var appModel:AppModel
    @State private var draft=TradingSettings.defaults
    @FocusState private var focused:String?
    var body:some View {
        Form {
            Section("المخاطرة") { number("المخاطرة %","risk",$draft.riskPct,"نسبة المخاطرة النقدية لكل صفقة."); number("الحد الأدنى للثقة %","confidence",$draft.minConfidence,"أقل ثقة يسمح بعدها بالدخول.") }
            Section("حدود التشغيل") {
                Stepper("حد المراكز: \(draft.maxPositions)",value:$draft.maxPositions,in:1...10)
                Stepper("حد الخسائر المتتالية: \(draft.maxConsecutiveLosses)",value:$draft.maxConsecutiveLosses,in:0...20)
                number("حد Equity اليومي %","equity",$draft.dailyLossLimitPct,"0 = معطل.")
                number("حد ربح الجلسة $","session",$draft.sessionProfitLimit,"يُحسب من Balance المحقق بعد إغلاق الصفقات. 0 = بدون حد.")
            }
            Section { Button { focused=nil; Task{await appModel.update(settings:draft)} } label:{ Label("حفظ التغييرات",systemImage:"checkmark.circle.fill").frame(maxWidth:.infinity) }.disabled(appModel.isPerformingCommand) }
        }.t4ListBackground().scrollDismissesKeyboard(.interactively).navigationTitle("المخاطرة والحدود").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItemGroup(placement:.keyboard){Spacer();Button("تم"){focused=nil}.fontWeight(.semibold)}}.onAppear{draft=appModel.snapshot?.settings ?? .defaults}
    }
    @ViewBuilder private func number(_ title:String,_ key:String,_ value:Binding<Double>,_ help:String)->some View {
        VStack(alignment:.leading,spacing:5) { HStack { Text(title); Spacer(); TextField("0",value:value,format:.number.precision(.fractionLength(0...2))).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation).submitLabel(.done).focused($focused,equals:key).onSubmit{focused=nil}.frame(width:105) }; Text(help).font(.caption2).foregroundStyle(.secondary) }
    }
}

private struct TradeManagementSettingsView: View {
    @EnvironmentObject private var appModel:AppModel
    @State private var draft=TradingSettings.defaults
    @FocusState private var focused:String?
    var body:some View {
        Form {
            Section {
                number("R:R Override","rr",$draft.rr,"0 = AI يختار SL/TP."); number("SL Points","sl",$draft.slPoints,"0 = AI"); number("TP Points","tp",$draft.tpPoints,"0 = AI"); number("الحماية %","protect",$draft.protectionPct,"0 = افتراضي الاستراتيجية"); number("بدء التتبع %","trailStart",$draft.trailingTriggerPct,"0 = افتراضي الاستراتيجية"); number("فجوة التتبع %","trail",$draft.trailingGapPct,"0 = افتراضي الاستراتيجية")
            } footer:{Text("القيمة 0 تعني استخدام الإعداد الافتراضي للمحرك/الاستراتيجية. لا توجد مدة زمنية للصفقة.")}
            Section { Button("إرجاع إدارة الصفقة للإعدادات التلقائية") { draft.rr=0; draft.slPoints=0; draft.tpPoints=0; draft.protectionPct=0; draft.trailingTriggerPct=0; draft.trailingGapPct=0 } }
            Section { Button { focused=nil; Task{await appModel.update(settings:draft)} } label:{ Label("حفظ التغييرات",systemImage:"checkmark.circle.fill").frame(maxWidth:.infinity) }.disabled(appModel.isPerformingCommand) }
        }.t4ListBackground().scrollDismissesKeyboard(.interactively).navigationTitle("إدارة الصفقة").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItemGroup(placement:.keyboard){Spacer();Button("تم"){focused=nil}.fontWeight(.semibold)}}.onAppear{draft=appModel.snapshot?.settings ?? .defaults}
    }
    @ViewBuilder private func number(_ title:String,_ key:String,_ value:Binding<Double>,_ help:String)->some View {
        VStack(alignment:.leading,spacing:5) { HStack { Text(title); Spacer(); TextField("0",value:value,format:.number.precision(.fractionLength(0...2))).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation).submitLabel(.done).focused($focused,equals:key).onSubmit{focused=nil}.frame(width:105) }; Text(help).font(.caption2).foregroundStyle(.secondary) }
    }
}

private struct NotificationSettingsView: View {
    @EnvironmentObject private var notificationManager:NotificationManager
    var body:some View {
        Form {
            Section("طريقة العرض") { Toggle("داخل التطبيق",isOn:$notificationManager.inAppEnabled); Toggle("إشعارات iOS",isOn:$notificationManager.outsideEnabled) }
            Section("أحداث البوت") { Toggle("فتح صفقة",isOn:$notificationManager.tradeOpened); Toggle("إغلاق صفقة",isOn:$notificationManager.tradeClosed); Toggle("حماية الربح",isOn:$notificationManager.profitProtection); Toggle("تم تحقيق هدف الجلسة 💵",isOn:$notificationManager.sessionGoal) }
            Section { LabeledContent("صلاحية iOS",value:notificationManager.authorizationStatusText) }
        }.t4ListBackground().navigationTitle("الإشعارات").navigationBarTitleDisplayMode(.inline).task{await notificationManager.refreshAuthorizationStatus()}
    }
}
