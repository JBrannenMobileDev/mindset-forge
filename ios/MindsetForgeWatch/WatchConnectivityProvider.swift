import Foundation
import WatchConnectivity
import WidgetKit

/// watchOS-side WatchConnectivity owner. Receives the phone's payload pushes,
/// publishes them to the glance UI, caches them for the complication, and
/// relays glance actions (e.g. "Mark done") back to the phone.
final class WatchConnectivityProvider: NSObject, ObservableObject {
    static let shared = WatchConnectivityProvider()

    @Published var payload: WatchPayload = WatchPayload.load()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends a "complete focus" command to the phone. Prefers an immediate
    /// `sendMessage` when reachable and falls back to a queued `transferUserInfo`
    /// so the action is never lost when the phone is asleep.
    func completeFocus() {
        let message = ["command": "completeFocus"]
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }

        // Optimistic local update so the glance reflects the tap immediately;
        // the phone's authoritative payload will follow.
        var optimistic = payload
        optimistic.focusCompleted = true
        optimistic.state = "on_track"
        optimistic.accentKind = "done"
        optimistic.canCompleteInWidget = false
        applyAndCache(optimistic)
    }

    private func applyAndCache(_ newPayload: WatchPayload) {
        DispatchQueue.main.async {
            self.payload = newPayload
        }
        if let data = try? JSONEncoder().encode(newPayload),
           let json = String(data: data, encoding: .utf8),
           let defaults = UserDefaults(suiteName: WatchPayload.appGroupId) {
            defaults.set(json, forKey: WatchPayload.payloadKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func handleContext(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        WatchPayload.save(from: context)
        let fresh = WatchPayload.load()
        DispatchQueue.main.async {
            self.payload = fresh
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchConnectivityProvider: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated {
            handleContext(session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleContext(applicationContext)
    }
}
