import Flutter
import Foundation
import WatchConnectivity

/// Bridges the Flutter `mindsetforge/watch` MethodChannel to WatchConnectivity.
///
/// Outbound: the app calls `updateContext` with the slim widget payload, which
/// we push to the watch via `updateApplicationContext` (latest-state-wins,
/// delivered even when the watch app is not running).
///
/// Inbound: watch glance actions arrive as `sendMessage` / `transferUserInfo`
/// and are forwarded to Dart as a `command` invocation (e.g. `completeFocus`).
final class WatchConnectivityBridge: NSObject {
    static let shared = WatchConnectivityBridge()

    private var channel: FlutterMethodChannel?
    private var latestContext: [String: Any]?

    func setup(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "mindsetforge/watch", binaryMessenger: messenger)
        channel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "updateContext":
                if let args = call.arguments as? [String: Any] {
                    self.pushContext(args)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func pushContext(_ context: [String: Any]) {
        latestContext = context
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(context)
        } catch {
            NSLog("WatchConnectivityBridge updateApplicationContext failed: \(error)")
        }
    }

    private func forwardCommand(_ command: String) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("command", arguments: command)
        }
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // Re-send the latest known context once the session is ready.
        if activationState == .activated, let context = latestContext {
            try? session.updateApplicationContext(context)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for a newly-paired watch.
        WCSession.default.activate()
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let command = message["command"] as? String {
            forwardCommand(command)
        }
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let command = message["command"] as? String {
            forwardCommand(command)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let command = userInfo["command"] as? String {
            forwardCommand(command)
        }
    }
}
