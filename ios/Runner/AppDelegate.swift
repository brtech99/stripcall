import Flutter
import UIKit
import Firebase
import WatchConnectivity

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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
