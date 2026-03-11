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

class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        // Set up notification categories with "On my way" action
        let onMyWayAction = UNNotificationAction(
            identifier: "ON_MY_WAY_ACTION",
            title: "On my way",
            options: [.foreground]
        )
        let problemCategory = UNNotificationCategory(
            identifier: "PROBLEM_CATEGORY",
            actions: [onMyWayAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([problemCategory])
        UNUserNotificationCenter.current().delegate = self

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

    // Handle notification action (On my way)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "ON_MY_WAY_ACTION" {
            let userInfo = response.notification.request.content.userInfo
            if let problemIdStr = userInfo["problemId"] as? String,
               let problemId = Int(problemIdStr) {
                WatchSessionManager.shared.goOnMyWay(problemId: problemId) { _, _ in }
            }
        }
        completionHandler()
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
