import SwiftUI
import UIKit

@main
struct T4BotApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connectionStore = ConnectionStore()
    @StateObject private var appModel = AppModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    init() {
        // Keep scrolling visually continuous with the page; no separator line appears
        // when the navigation bar transitions between scroll-edge and compact states.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(connectionStore)
                .environmentObject(appModel)
                .environmentObject(notificationManager)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.scheme)
                .task {
                    if let configuration = connectionStore.configuration {
                        appModel.connect(using: configuration)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        appModel.sceneBecameActive()
                    case .inactive, .background:
                        appModel.sceneBecameInactive()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
