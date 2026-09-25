import SwiftUI
import UIKit

final class T4BotAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in APNsDiagnostics.shared.registered(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in APNsDiagnostics.shared.failed(error) }
    }
}

@main
struct T4BotApp: App {
    @UIApplicationDelegateAdaptor(T4BotAppDelegate.self) private var appDelegate
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
                    case .active: appModel.sceneBecameActive()
                    case .inactive, .background: appModel.sceneBecameInactive()
                    @unknown default: break
                    }
                }
        }
    }
}
