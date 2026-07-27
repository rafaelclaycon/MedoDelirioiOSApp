import Foundation

enum PushNotificationType: String {

    case newEpisode = "new_episode"
    case weeklyTopSounds = "weekly_top_sounds"
    case weeklyTopReactions = "weekly_top_reactions"
    case contentUpdate = "content_update"
}

extension Notification.Name {

    static let navigateToTab = Notification.Name("navigateToTab")
    static let navigateToTrends = Notification.Name("navigateToTrends")
}

enum NavigateToTabKey {

    static let phoneTab = "phoneTab"
}
