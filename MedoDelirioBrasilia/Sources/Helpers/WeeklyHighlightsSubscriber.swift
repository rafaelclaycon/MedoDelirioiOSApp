import Foundation

enum WeeklyHighlightsSubscriber {

    static func subscribe() async -> Result<Void, Error> {
        do {
            try await APIClient.shared.subscribeToChannel("weekly_highlights")
            UserSettings().setWeeklyHighlightsOptedOut(to: false)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func unsubscribe() async -> Result<Void, Error> {
        do {
            try await APIClient.shared.unsubscribeFromChannel("weekly_highlights")
            UserSettings().setWeeklyHighlightsOptedOut(to: true)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
