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
        .overlay(alignment: .top) {
            if let message = appModel.operationMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .animation(.snappy, value: appModel.operationMessage)
        .task(id: appModel.operationMessage) {
            guard let message = appModel.operationMessage else { return }
            try? await Task.sleep(for: .seconds(3))
            if appModel.operationMessage == message {
                appModel.operationMessage = nil
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
