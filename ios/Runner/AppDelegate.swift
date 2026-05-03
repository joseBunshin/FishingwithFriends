import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Explicit APNs registration at app launch. The firebase_messaging
    // plugin normally handles this, but with the implicit-engine
    // AppDelegate pattern Flutter introduced in 3.41+, plugin
    // registration happens AFTER didFinishLaunchingWithOptions has
    // already returned. By that point, iOS's "register for remote
    // notifications" window has closed for this launch — and
    // getAPNSToken() returns nil forever because iOS was never asked.
    //
    // Calling registerForRemoteNotifications() here forces iOS to do
    // the handshake immediately. The token then arrives at
    // FlutterAppDelegate.application(_:didRegisterForRemoteNotifications
    // WithDeviceToken:) which forwards to all registered plugins,
    // including firebase_messaging.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
