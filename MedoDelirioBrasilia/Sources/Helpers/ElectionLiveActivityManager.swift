//
//  ElectionLiveActivityManager.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/09/26.
//

import ActivityKit
import Foundation

/// Starts and ends the election Live Activity. Updates don't go through the app: the server
/// sends one APNs broadcast push to the channel and iOS updates every subscribed activity.
@MainActor
final class ElectionLiveActivityManager {

    static let shared = ElectionLiveActivityManager()

    enum StartError: LocalizedError {
        case activitiesDisabled
        case featureDisabled
        case missingChannel
        case missingState

        var errorDescription: String? {
            switch self {
            case .activitiesDisabled:
                "As Atividades ao Vivo estão desativadas. Ative em Ajustes > Medo e Delírio."
            case .featureDisabled, .missingChannel, .missingState:
                "O acompanhamento da apuração ainda não está disponível. Tente novamente mais tarde."
            }
        }
    }

    /// Without a push for this long, the widget shows the update as late.
    static let staleInterval: TimeInterval = 15 * 60

    private init() { }

    /// Ended activities stay in `activities` while their result is still on the Lock Screen,
    /// but they no longer update, so they don't count.
    private var liveActivities: [Activity<ElectionActivityAttributes>] {
        Activity<ElectionActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
    }

    var isRunning: Bool {
        !liveActivities.isEmpty
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// The server switch is the public launch; the local flag lets testers in before that,
    /// since beta and production builds talk to the same server.
    static func isAvailable(_ info: ElectionLiveInfo) -> Bool {
        info.enabled || FeatureFlag.isEnabled(.electionLiveActivity)
    }

    func start(apiClient: APIClient = .shared) async throws {
        guard areActivitiesEnabled else { throw StartError.activitiesDisabled }

        let info = try await apiClient.electionLiveInfo()
        guard Self.isAvailable(info) else { throw StartError.featureDisabled }
        guard let channelId = info.channelId else { throw StartError.missingChannel }
        guard let state = info.state else { throw StartError.missingState }

        // A second tap shouldn't stack a duplicate activity for the same round.
        if liveActivities.contains(where: { $0.attributes.round == info.round }) {
            return
        }

        _ = try Activity.request(
            attributes: ElectionActivityAttributes(round: info.round),
            content: ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(Self.staleInterval)),
            pushType: .channel(channelId)
        )
        ChannelLogStore.shared.logEvent("Live Activity da eleição iniciada (turno \(info.round))", success: true)
    }

    func endAll() async {
        for activity in Activity<ElectionActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
