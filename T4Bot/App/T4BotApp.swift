import SwiftUI

@main
struct T4BotApp: App {
    @StateObject private var connectionStore = ConnectionStore()
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(connectionStore)
                .environmentObject(appModel)
                .environment(\.layoutDirection, .rightToLeft)
                .task {
                    if let configuration = connectionStore.configuration {
                        appModel.connect(using: configuration)
                    }
                }
        }
    }
}
