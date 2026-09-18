//
//  WatchSync.swift
//  iPrayerWatch
//
//  The watch side of the iPhone link: receives settings and the phone's location, sends back the
//  Tasbih and tracker changes made on the wrist.
//

import Foundation
import WatchConnectivity

@MainActor
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()
    
    private var pushTask: Task<Void, Never>?
    
    private override init() {
        super.init()
    }
    
    func activate() {
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    /// Coalesces a burst of taps into one update
    func schedulePush() {
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            push()
        }
    }
    
    func push() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let context = WatchSyncPayload.localProgress().asContext()
        // The context reaches the phone whenever it next wakes; a message gets there now if it is reachable
        try? session.updateApplicationContext(context)
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }
    
    // MARK: - WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        // Whatever the phone last shared is already waiting in the received context
        let context = session.receivedApplicationContext
        guard let payload = WatchSyncPayload.from(context) else { return }
        Task { @MainActor in WatchModel.shared.apply(payload) }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let payload = WatchSyncPayload.from(applicationContext) else { return }
        Task { @MainActor in WatchModel.shared.apply(payload) }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let payload = WatchSyncPayload.from(message) else { return }
        Task { @MainActor in WatchModel.shared.apply(payload) }
    }
}
