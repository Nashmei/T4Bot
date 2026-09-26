import SwiftUI

struct AccountView:View {
    @EnvironmentObject private var appModel:AppModel
    @EnvironmentObject private var connectionStore:ConnectionStore
    @State private var showLogin=false
    @State private var showDisconnect=false
    var body:some View {
        NavigationStack {
            ZStack {
                AppBackdrop()
                ScrollView {
                    VStack(spacing:16) {
                        if let a=appModel.snapshot?.account {
                            HeroCard {
                                HStack(spacing:16) {
                                    ZStack {Circle().fill(.white.opacity(0.15)).frame(width:62,height:62);Image(systemName:"person.crop.circle.fill").font(.system(size:38))}
                                    VStack(alignment:.leading,spacing:5) {
                                        Text("MT5 • "+String(a.login)).font(.title3.bold()).monospacedDigit()
                                        Text(a.isDemo ? "حساب Demo":"حساب Real").font(.caption).opacity(0.85)
                                        Text(a.server).font(.caption2).opacity(0.65).lineLimit(1)
                                    }
                                    Spacer()
                                }
                            }
                            SurfaceCard {
                                VStack(spacing:14) {
                                    value("الرصيد",a.balance,a.currency); Divider()
                                    value("Equity",a.equity,a.currency); Divider()
                                    value("الهامش الحر",a.marginFree,a.currency)
                                }
                            }
                        } else {
                            ContentUnavailableView("MT5 غير متصل",systemImage:"person.crop.circle.badge.exclamationmark",description:Text("اربط حساب MT5 للمتابعة.")).padding(.vertical,35)
                        }
                        SurfaceCard {
                            VStack(spacing:12) {
                                Button {showLogin=true} label:{Label("تغيير حساب MT5",systemImage:"person.badge.key").frame(maxWidth:.infinity)}
                                    .buttonStyle(.borderedProminent).tint(T4Palette.accent).disabled(appModel.snapshot?.engine.running == true)
                                Button("تسجيل الخروج من T4Bot",role:.destructive){showDisconnect=true}.frame(maxWidth:.infinity)
                            }
                        }
                    }.padding(16)
                }
            }.navigationTitle("الحساب").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:$showLogin){MT5LoginView()}
            .confirmationDialog("تسجيل الخروج؟",isPresented:$showDisconnect,titleVisibility:.visible){
                Button("تسجيل الخروج",role:.destructive){appModel.disconnect();connectionStore.clear()}
                Button("إلغاء",role:.cancel){}
            }
        }
    }
    private func value(_ t:String,_ v:Double,_ c:String)->some View {HStack{Text(t).foregroundStyle(.secondary);Spacer();Text(v.formatted(.currency(code:c))).font(.headline.monospacedDigit())}}
}

private struct MT5LoginView:View {
    @EnvironmentObject private var appModel:AppModel
    @Environment(.dismiss) private var dismiss
    @State private var server="MetaQuotes-Demo",login="",password=""
    var body:some View {
        NavigationStack {
            ZStack {
                AppBackdrop()
                ScrollView {
                    VStack(spacing:18) {
                        BrandHeader()
                        SurfaceCard {
                            VStack(spacing:14) {
                                field("السيرفر","building.2.fill"){TextField("MetaQuotes-Demo",text:$server).textInputAutocapitalization(.never).autocorrectionDisabled()}
                                field("رقم الحساب","number"){TextField("Login",text:$login).keyboardType(.numberPad)}
                                field("كلمة مرور MT5","key.fill"){SecureField("Password",text:$password).textInputAutocapitalization(.never)}
                            }
                        }
                        Button {
                            guard let n=Int64(login),!server.isEmpty,!password.isEmpty else{appModel.errorMessage="تحقق من بيانات MT5.";return}
                            Task{let ok=await appModel.login(server:server,login:n,password:password);password="";if ok{dismiss()}}
                        } label:{Label("ربط الحساب",systemImage:"lock.open.fill").fontWeight(.bold).frame(maxWidth:.infinity).padding(.vertical,10)}
                            .buttonStyle(.borderedProminent).tint(T4Palette.accent).disabled(appModel.isPerformingCommand)
                        Text("كلمة مرور MT5 تستخدم للاتصال فقط ولا تحفظ داخل التطبيق.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding(18)
                }
            }.navigationTitle("ربط MT5").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.cancellationAction){Button("إلغاء"){password="";dismiss()}}}
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }
    private func field<C:View>(_ title:String,_ icon:String,@ViewBuilder content:()->C)->some View {
        VStack(alignment:.leading,spacing:7){Label(title,systemImage:icon).font(.caption.bold()).foregroundStyle(.secondary);content().padding(13).background(.primary.opacity(0.045),in:RoundedRectangle(cornerRadius:14))}
    }
}
private struct BrandHeader:View {
    var body:some View {VStack(spacing:10){ZStack{Circle().fill(LinearGradient(colors:[T4Palette.accent,.cyan],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:82,height:82);BrandMark(size:58)};Text("حساب MetaTrader 5").font(.title3.bold())}}
}
