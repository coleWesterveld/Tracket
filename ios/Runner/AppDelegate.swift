import Flutter
import UIKit

// Added some  code required by notifications package
// https://pub.dev/packages/flutter_local_notifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let liveActivityBridge = LiveActivityBridge()
  private let homeWidgetBridge = HomeWidgetBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // This is required to make any communication available in the action isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Both deep links are recorded rather than acted on: the Dart side drains the
  // flag on its next resume, which is the only way a URL that lands during a
  // cold launch can still be honoured.
  //
  //   tracket://finish            the Live Activity's Finish pill
  //   tracket://open?tab=schedule a home screen widget
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if liveActivityBridge.handle(url: url) { return true }
    if homeWidgetBridge.handle(url: url) { return true }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityBridge") {
      liveActivityBridge.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HomeWidgetBridge") {
      homeWidgetBridge.register(with: registrar.messenger())
    }
  }
}
