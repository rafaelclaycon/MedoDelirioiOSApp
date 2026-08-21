//
//  WatchPairingChecker.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/08/26.
//

import Foundation
import WatchConnectivity

/// Reads whether an Apple Watch is paired to this iPhone, for analytics only — the app
/// has no watch target and doesn't otherwise use WatchConnectivity.
enum WatchPairingChecker {

    /// nil when the platform doesn't support pairing at all (iPad, Mac) or activation
    /// fails, so callers can tell "not applicable" apart from "checked, not paired".
    ///
    /// `isPaired` only reflects reality once the session has activated at least once,
    /// hence the wait — reading it beforehand would misreport every paired watch as
    /// absent.
    @MainActor
    static func isWatchPaired() async -> Bool? {
        guard WCSession.isSupported() else { return nil }

        let session = WCSession.default
        let delegate = ActivationDelegate()
        // Held by the continuation closure for as long as it takes to resume, then
        // released — nothing here needs to outlive one activation.
        session.delegate = delegate

        return await withCheckedContinuation { continuation in
            delegate.onActivationComplete = {
                continuation.resume(returning: session.isPaired)
            }
            session.activate()
        }
    }

    /// `WCSessionDelegate` callbacks land on an arbitrary queue, not necessarily main,
    /// so this only stores a closure and never touches UI itself.
    private final class ActivationDelegate: NSObject, WCSessionDelegate {

        var onActivationComplete: (() -> Void)?

        func session(
            _ session: WCSession,
            activationDidCompleteWith activationState: WCSessionActivationState,
            error: Error?
        ) {
            onActivationComplete?()
        }

        func sessionDidBecomeInactive(_ session: WCSession) {}
        func sessionDidDeactivate(_ session: WCSession) {}
    }
}
