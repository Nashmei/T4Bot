import SwiftUI

struct SettingsView:View {
    @EnvironmentObject private var appModel:AppModel
    @EnvironmentObject private var notificationManager:NotificationManager
    @State private var draft=TradingSettings.defaults
    @State private var loadedAccount:Int64?
    @State private var hasEdits=false
    @FocusState private var focused:Bool
    @AppStorage("appearance") private var appearance=AppAppearance.system.rawValue

    var body:some View {
        NavigationStack {
            ZStack {
                AppBackdrop()
                Form {
                    Section {
                        Picker("المظهر",selection:$appearance) { ForEach(AppAppearance.allCases){ Text($0.title).tag($0.rawValue) } }.pickerStyle(.segmented)
                    } header:{SettingsHeader("المظهر","circle.lefthalf.filled")}
                    Section {
                        row("المخاطرة %",$draft.riskPct,"تحدد حجم المخاطرة النقدية.")
                        row("الثقة %",$draft.minConfidence,"أقل ثقة للدخول.")
                        Stepper("حد المراكز: \(draft.maxPositions)",value:$draft.maxPositions,in:1...10)
                        Stepper("حد الخسائر: \(draft.maxConsecutiveLosses)",value:$draft.maxConsecutiveLosses,in:0...20)
                        row("حد Equity اليومي %",$draft.dailyLossLimitPct,"0 = معطل.")
                    } header:{SettingsHeader("المخاطرة وحدود التداول","shield.lefthalf.filled")}
                    Section {
                        row("R:R Override",$draft.rr,"0 = AI يختار SL/TP والمحرك يحسب R:R الفعلي.")
                        row("SL Points",$draft.slPoints,"0 = AI")
                        row("TP Points",$draft.tpPoints,"0 = AI")
                        row("الحماية %",$draft.protectionPct,"0 = AI")
                        row("Trailing Gap %",$draft.trailingGapPct,"0 = AI")
                        row("المدة بالدقائق",$draft.maxTradeMinutes,"0 = AI")
                        Button("إرجاع إدارة الصفقة إلى AI") {
                            draft.rr=0; draft.slPoints=0; draft.tpPoints=0; draft.protectionPct=0; draft.trailingGapPct=0; draft.maxTradeMinutes=0
                        }
                    } header:{SettingsHeader("إدارة الصفقة","brain.head.profile")} footer:{Text("القيمة 0 تعني أن AI يديرها تلقائياً. اختيار الأزواج موجود في صفحة التحليل.")}
                    Section {
                        Toggle("داخل التطبيق",isOn:$notificationManager.inAppEnabled)
                        Toggle("إشعارات iOS",isOn:$notificationManager.outsideEnabled)
                        Toggle("فتح صفقة",isOn:$notificationManager.tradeOpened)
                        Toggle("إغلاق صفقة",isOn:$notificationManager.tradeClosed)
                        Toggle("حماية الربح",isOn:$notificationManager.profitProtection)
                    } header:{SettingsHeader("الإشعارات","bell.fill")}
                    Section {
                        Button { focused=false; Task { await appModel.update(settings:draft); hasEdits=false } } label:{
                            Label("حفظ الإعدادات",systemImage:"checkmark.circle.fill").frame(maxWidth:.infinity)
                        }.disabled(appModel.isPerformingCommand)
                    }
                }.t4ListBackground()
            }
            .navigationTitle("الإعدادات").navigationBarTitleDisplayMode(.inline)
            .onAppear { load(force:true); Task { await notificationManager.refreshAuthorizationStatus() } }
            .onChange(of:appModel.snapshot){_,_ in load(force:false)}
            .onChange(of:draft){_,_ in hasEdits=true}
            .toolbar { ToolbarItemGroup(placement:.keyboard){Spacer();Button("تم"){focused=false}} }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }
    private func load(force:Bool) {
        guard let s=appModel.snapshot else{return}; let a=s.account?.login
        guard force || loadedAccount != a || !hasEdits else{return}
        draft=s.settings; loadedAccount=a; hasEdits=false
    }
    @ViewBuilder private func row(_ title:String,_ value:Binding<Double>,_ help:String)->some View {
        VStack(alignment:.leading,spacing:4) {
            LabeledContent(title){TextField(title,value:value,format:.number.precision(.fractionLength(0...2))).multilineTextAlignment(.trailing).keyboardType(.decimalPad).focused($focused).frame(maxWidth:110)}
            Text(help).font(.caption2).foregroundStyle(.secondary)
        }
    }
}


private struct SettingsHeader:View {
    let title:String; let icon:String
    init(_ title:String,_ icon:String){self.title=title;self.icon=icon}
    var body:some View {Label(title,systemImage:icon).font(.caption.bold()).foregroundStyle(T4Palette.accent)}
}
