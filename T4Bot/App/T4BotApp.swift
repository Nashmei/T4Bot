import SwiftUI

@main
struct T4BotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connectionStore = ConnectionStore()
    @StateObject private var appModel = AppModel()
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(connectionStore)
                .environmentObject(appModel)
                .environmentObject(notificationManager)
                .environment(\.layoutDirection, .rightToLeft)
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
