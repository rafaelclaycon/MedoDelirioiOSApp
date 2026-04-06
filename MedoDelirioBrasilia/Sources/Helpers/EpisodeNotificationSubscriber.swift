import Foundation

enum EpisodeNotificationSubscriber {

    static func subscribe() async -> Result<Void, Error> {
        do {
            try await APIClient.shared.subscribeToChannel("new_episodes")
            UserSettings().setEnableEpisodeNotifications(to: true)
            return .success(())
        } catch {
            UserSettings().setEnableEpisodeNotifications(to: false)
            Task { await AnalyticsService().send(originatingScreen: "EpisodeNotificationSubscriber", action: "episode_notifications_subscribe_failed") }
            return .failure(error)
        }
    }

    static func unsubscribe() async -> Result<Void, Error> {
        do {
            try await APIClient.shared.unsubscribeFromChannel("new_episodes")
            UserSettings().setEnableEpisodeNotifications(to: false)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
