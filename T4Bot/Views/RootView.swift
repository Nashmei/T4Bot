import SwiftUI

struct RootView: View {
    enum Tab: Hashable { case cockpit, market, positions, account }

    @EnvironmentObject private var appModel: AppModel
    @State private var selection: Tab = .cockpit

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { DashboardView() }
                .tabItem { Label("المحرك", systemImage: "gauge.with.dots.needle.50percent") }
                .tag(Tab.cockpit)

            NavigationStack { AnalysisView() }
                .tabItem { Label("السوق", systemImage: "waveform.path.ecg") }
                .tag(Tab.market)

            NavigationStack { PositionsView() }
                .tabItem { Label("الصفقات", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.positions)

            NavigationStack { AccountView() }
                .tabItem { Label("الحساب", systemImage: "person.crop.circle") }
                .tag(Tab.account)
        }
        .tint(T4Palette.accent)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
