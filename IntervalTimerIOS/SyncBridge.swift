import Foundation
import WatchConnectivity

/// Sends the iPhone's settings to the Apple Watch (latest value wins, delivered in the background).
/// iPhone: call `push(_:)` whenever settings change. Watch: set `onReceive`.
final class SyncBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = SyncBridge()
    private static let key = "settings"

    /// Called on the main queue when settings arrive (watch side).
    var onReceive: ((Settings) -> Void)?

    private let lock = NSLock()
    private var pending: Data?
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let s = session else { return }
        s.delegate = self
        s.activate()
    }

    /// iPhone side.
    func push(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        lock.lock(); pending = data; lock.unlock()
        sendIfPossible()
    }

    private func sendIfPossible() {
        guard let s = session, s.activationState == .activated else { return }
        #if os(iOS)
        guard s.isPaired, s.isWatchAppInstalled else { return }
        #endif
        lock.lock(); let data = pending; lock.unlock()
        guard let data else { return }
        try? s.updateApplicationContext([Self.key: data])
    }

    private func handle(_ context: [String: Any]) {
        guard let data = context[Self.key] as? Data,
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in self?.onReceive?(settings) }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        sendIfPossible()
        handle(session.receivedApplicationContext)   // picks up what the phone sent while the watch app wasn't running
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionWatchStateDidChange(_ session: WCSession) { sendIfPossible() }   // e.g. the watch app was just installed
    #endif
}
