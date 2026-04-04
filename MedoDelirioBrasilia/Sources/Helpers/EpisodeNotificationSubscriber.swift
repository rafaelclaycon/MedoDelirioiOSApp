import Foundation

enum EpisodeNotificationSubscriber {

    static func subscribe() async -> Result<Void, Error> {
        do {
            try await APIClient.shared.subscribeToChannel("new_episodes")
            UserSettings().setEnableEpisodeNotifications(to: true)
            return .success(())
        } catch {
            UserSettings().setEnableEpisodeNotifications(to: false)
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
