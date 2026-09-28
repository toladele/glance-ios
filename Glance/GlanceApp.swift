import SwiftUI

@main
struct GlanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = WatcherStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    await PushManager.shared.requestAuthorization()
                }
        }
    }
}
