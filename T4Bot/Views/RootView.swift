import SwiftUI

struct RootView: View {
    @EnvironmentObject private var connectionStore: ConnectionStore
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            if connectionStore.isConfigured {
                MainTabView()
            } else {
                ConnectionView()
            }
        }
        .alert(
            "T4Bot",
            isPresented: Binding(
                get: { appModel.errorMessage != nil },
                set: { if !$0 { appModel.errorMessage = nil } }
            )
        ) {
            Button("حسناً", role: .cancel) {
                appModel.errorMessage = nil
            }
        } message: {
            Text(appModel.errorMessage ?? "")
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("الرئيسية", systemImage: "gauge.with.dots.needle.67percent") }

            AnalysisView()
                .tabItem { Label("التحليل", systemImage: "waveform.path.ecg") }

            PositionsView()
                .tabItem { Label("الصفقات", systemImage: "list.bullet.rectangle.portrait") }

            SettingsView()
                .tabItem { Label("الإعدادات", systemImage: "slider.horizontal.3") }

            AccountView()
                .tabItem { Label("الحساب", systemImage: "person.crop.circle") }
        }
    }
}
