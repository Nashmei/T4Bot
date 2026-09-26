import SwiftUI

struct ConnectionView:View {
    @EnvironmentObject private var connectionStore:ConnectionStore
    @EnvironmentObject private var appModel:AppModel
    @FocusState private var passwordFocused:Bool
    var body:some View {
        ZStack {
            LinearGradient(colors:[Color(red:0.94,green:0.96,blue:1),Color(red:0.985,green:0.99,blue:1)],startPoint:.top,endPoint:.bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing:28) {
                    Spacer(minLength:70)
                    ZStack {
                        Circle().fill(LinearGradient(colors:[T4Palette.accent,Color(red:0.25,green:0.69,blue:0.96)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:112,height:112)
                        BrandMark(size:78)
                    }.shadow(color:T4Palette.accent.opacity(0.22),radius:28,y:14)
                    VStack(spacing:7) {
                        Text("T4Bot").font(.system(size:40,weight:.black,design:.rounded))
                        Text("تحكم سريع وآمن بحساب MT5").font(.subheadline).foregroundStyle(.secondary)
                    }
                    SurfaceCard {
                        VStack(spacing:16) {
                            HStack {
                                VStack(alignment:.leading,spacing:3){Text("تسجيل الدخول").font(.title3.bold());Text("أدخل رمز الوصول الخاص بك").font(.caption).foregroundStyle(.secondary)}
                                Spacer(); Image(systemName:"lock.shield.fill").foregroundStyle(T4Palette.accent)
                            }
                            HStack {
                                Image(systemName:"key.fill").foregroundStyle(.secondary)
                                SecureField("رمز الوصول",text:$connectionStore.password).textContentType(.password).focused($passwordFocused).submitLabel(.go).onSubmit{login()}
                            }.padding(15).background(.primary.opacity(0.045),in:RoundedRectangle(cornerRadius:16))
                            if let m=connectionStore.validationMessage { Text(m).font(.footnote).foregroundStyle(T4Palette.negative).frame(maxWidth:.infinity,alignment:.leading) }
                            Button(action:login) {
                                HStack { if appModel.isPerformingCommand{ProgressView().tint(.white)}; Text("دخول").fontWeight(.bold) }.frame(maxWidth:.infinity).padding(.vertical,11)
                            }.buttonStyle(.borderedProminent).tint(T4Palette.accent)
                            .disabled(appModel.isPerformingCommand || connectionStore.password.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                        }
                    }
                    Label("يحفظ رمز الوصول بأمان في Keychain",systemImage:"checkmark.shield.fill").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength:30)
                }.padding(.horizontal,22)
            }
        }.preferredColorScheme(nil)
    }
    private func login(){
        passwordFocused=false
        guard let c=connectionStore.candidateConfiguration else{connectionStore.validationMessage="أدخل رمز الوصول.";return}
        Task {
            guard await appModel.validateConnection(using:c) else{connectionStore.validationMessage="تعذر تسجيل الدخول.";return}
            guard connectionStore.save() else{return}; appModel.connect(using:c)
        }
    }
}
