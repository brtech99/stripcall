import Flutter
import UIKit
import Firebase
import WatchConnectivity
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    // Initialize WatchConnectivity bridge
    if let controller = window?.rootViewController as? FlutterViewController {
      WatchSessionManager.shared.configure(with: controller)
    }

    // Register notification category with "On my way" action
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle notification action (On my way)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.actionIdentifier == "ON_MY_WAY_ACTION" {
      let userInfo = response.notification.request.content.userInfo
      if let problemIdStr = userInfo["problemId"] as? String,
         let problemId = Int(problemIdStr) {
        WatchSessionManager.shared.handleOnMyWay(problemId: problemId)
      }
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
