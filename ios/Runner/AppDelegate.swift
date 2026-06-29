import Flutter
import UIKit
import home_widget

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register Flutter plugins for the background isolate that the widget's
    // interactive "Mark done" App Intent spins up (iOS 17+), so Firebase and
    // other plugins are available inside `widgetInteractiveCallback`.
    if #available(iOS 17.0, *) {
      HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
      }
    }

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Wire the WatchConnectivity bridge once the Flutter engine is attached.
    if let controller = window?.rootViewController as? FlutterViewController {
      WatchConnectivityBridge.shared.setup(messenger: controller.binaryMessenger)
    }

    return result
  }
}
