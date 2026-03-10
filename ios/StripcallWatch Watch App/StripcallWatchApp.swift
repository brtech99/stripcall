import SwiftUI
import WatchKit
import UserNotifications

@main
struct StripcallWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    WKApplication.shared().registerForRemoteNotifications()
                }
            }
        }
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        // Token handled by iPhone companion app via FCM
    }
}
