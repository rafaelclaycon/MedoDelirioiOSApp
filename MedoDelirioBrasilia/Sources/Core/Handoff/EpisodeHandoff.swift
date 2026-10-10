//
//  EpisodeHandoff.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Foundation
import os

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "EpisodeHandoff")

/// Where the player was at a given moment, and how fast it was moving. The same model
/// as the lock screen's elapsed time and rate: the position can be worked out for any
/// later moment without asking the player again.
struct EpisodePlaybackSnapshot: Equatable {

    var episodeID: String
    var position: TimeInterval
    var duration: TimeInterval
    /// Zero while paused.
    var rate: Double
    var takenAt: Date

    func payload(at date: Date) -> EpisodeHandoffPayload {
        let elapsed = max(date.timeIntervalSince(takenAt), 0) * rate
        return EpisodeHandoffPayload(
            episodeID: episodeID,
            position: min(position + elapsed, duration),
            duration: duration
        )
    }
}

/// Advertises the episode loaded in the player over Handoff, so a nearby device on the
/// same Apple Account can pick it up where this one is. When another device does,
/// `onContinuedElsewhere` runs so this one can pause.
///
/// The system asks for the payload on its own thread, at the moment the other device
/// wants it. Answering from a snapshot taken on every player change keeps the position
/// current to the second without touching the player off the main thread.
///
/// `@unchecked Sendable`: the activity is only touched on the main actor, and the
/// snapshot, the one thing the delegate callbacks read, sits behind a lock.
final class EpisodeHandoff: NSObject, NSUserActivityDelegate, @unchecked Sendable {

    private let onContinuedElsewhere: @MainActor () -> Void
    private let snapshot = OSAllocatedUnfairLock<EpisodePlaybackSnapshot?>(initialState: nil)

    @MainActor private var activity: NSUserActivity?
    @MainActor private var advertisedEpisodeID: String?

    init(onContinuedElsewhere: @escaping @MainActor () -> Void) {
        self.onContinuedElsewhere = onContinuedElsewhere
    }

    /// Call on every change to the player: play, pause, seek, speed, chapter.
    @MainActor
    func update(episode: PodcastEpisode, position: TimeInterval, duration: TimeInterval, isPlaying: Bool, rate: Float) {
        guard duration > 0 else { return }

        let newSnapshot = EpisodePlaybackSnapshot(
            episodeID: episode.id,
            position: position,
            duration: duration,
            rate: isPlaying ? Double(rate) : 0,
            takenAt: Date()
        )
        snapshot.withLock { $0 = newSnapshot }

        if advertisedEpisodeID != episode.id {
            activity?.invalidate()
            activity = makeActivity(for: episode, payload: newSnapshot.payload(at: newSnapshot.takenAt))
            advertisedEpisodeID = episode.id
            logger.info("[Handoff] advertising \(episode.id, privacy: .public) at \(Int(position))s")
        } else {
            activity?.needsSave = true
        }

        // The Siri-suggestion activities on other screens become current as they appear
        // and would quietly take Handoff away from the episode. Claiming it back on
        // every player change keeps the episode advertised; their donations already
        // happened when they became current.
        activity?.becomeCurrent()
    }

    /// Call when the player unloads the episode.
    @MainActor
    func end() {
        guard activity != nil else { return }
        activity?.invalidate()
        activity = nil
        advertisedEpisodeID = nil
        snapshot.withLock { $0 = nil }
        logger.info("[Handoff] stopped advertising")
    }

    @MainActor
    private func makeActivity(for episode: PodcastEpisode, payload: EpisodeHandoffPayload) -> NSUserActivity {
        let activity = NSUserActivity(activityType: Shared.ActivityTypes.continueEpisode)
        activity.title = episode.title
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPrediction = false
        // Opens the episode page in Safari on a device without the app.
        activity.webpageURL = URL(string: APIConfig.baseLinkURL + "episodio/\(episode.id)")
        activity.requiredUserInfoKeys = EpisodeHandoffPayload.requiredKeys
        activity.userInfo = payload.userInfo
        activity.delegate = self
        return activity
    }

    // MARK: - NSUserActivityDelegate

    func userActivityWillSave(_ userActivity: NSUserActivity) {
        guard
            let current = snapshot.withLock({ $0 }),
            userActivity.userInfo?[EpisodeHandoffPayload.Key.episodeID] as? String == current.episodeID
        else { return }

        let payload = current.payload(at: Date())
        userActivity.addUserInfoEntries(from: payload.userInfo)
        logger.debug("[Handoff] refreshed payload: \(payload.episodeID, privacy: .public) at \(Int(payload.position))s")
    }

    func userActivityWasContinued(_ userActivity: NSUserActivity) {
        logger.info("[Handoff] continued on another device; pausing here")
        Task { @MainActor in
            self.onContinuedElsewhere()
        }
    }
}
