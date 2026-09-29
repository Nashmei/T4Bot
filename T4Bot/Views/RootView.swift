import SwiftUI

struct RootView:View {
    @EnvironmentObject private var connectionStore:ConnectionStore
    @EnvironmentObject private var appModel:AppModel

    var body:some View {
        Group {
            if connectionStore.isConfigured { MainTabView() }
            else { ConnectionView() }
        }
        .tint(T4Palette.accent)
        .overlay(alignment:.top) {
            if let m=appModel.errorMessage {
                ToastBanner(message:m,success:false)
                    .onTapGesture{appModel.errorMessage=nil}
            } else if let m=appModel.operationMessage {
                ToastBanner(message:m,success:true)
            }
        }
        .animation(.snappy,value:appModel.operationMessage)
        .animation(.snappy,value:appModel.errorMessage)
        .task(id:appModel.operationMessage) {
            guard let m=appModel.operationMessage else{return}
            try? await Task.sleep(for:.seconds(2.4))
            if appModel.operationMessage==m {appModel.operationMessage=nil}
        }
    }
}

private struct ToastBanner:View {
    let message:String
    let success:Bool

    var body:some View {
        HStack(spacing:11) {
            Image(systemName:success ? "checkmark.circle.fill":"exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(success ? T4Palette.positive:.orange)
            Text(message).font(.subheadline.weight(.semibold)).lineLimit(3)
            Spacer()
        }
        .padding(14)
        .background(.regularMaterial,in:RoundedRectangle(cornerRadius:18,style:.continuous))
        .shadow(color:.black.opacity(0.08),radius:14,y:6)
        .padding(.horizontal,16)
        .padding(.top,8)
        .transition(.move(edge:.top).combined(with:.opacity))
    }
}

private struct MainTabView:View {
    var body:some View {
        TabView {
            DashboardView().tabItem{Label("الرئيسية",systemImage:"house.fill")}
            AnalysisView().tabItem{Label("التحليل",systemImage:"waveform.path.ecg")}
            PositionsView().tabItem{Label("الصفقات",systemImage:"arrow.up.arrow.down.circle.fill")}
            PerformanceView().tabItem{Label("الأداء",systemImage:"chart.bar.fill")}
            AccountView().tabItem{Label("الحساب",systemImage:"person.crop.circle")}
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
