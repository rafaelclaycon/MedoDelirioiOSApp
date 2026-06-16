import Foundation

/// Waiter as in the person who waits tables.
class UserActivityWaiter {
    
    /// - Parameters:
    ///   - persistentIdentifier: Pass a stable value (e.g. one derived from a reaction's ID) so repeated
    ///     visits reinforce the same Siri suggestion. Defaults to a random UUID for one-off activities.
    ///   - userInfo: Extra data the continuation handler needs to know *which* item to open (e.g. a reaction ID).
    static func getDonatableActivity(
        withType activityType: String,
        andTitle activityTitle: String,
        persistentIdentifier: String? = nil,
        userInfo: [String: String]? = nil
    ) -> NSUserActivity {
        let currentActivity = NSUserActivity(activityType: activityType)
        currentActivity.title = activityTitle
        currentActivity.isEligibleForHandoff = false
        currentActivity.isEligibleForPrediction = true
        currentActivity.isEligibleForSearch = true
        currentActivity.persistentIdentifier = persistentIdentifier ?? UUID().uuidString
        if let userInfo {
            currentActivity.userInfo = userInfo
            currentActivity.requiredUserInfoKeys = Set(userInfo.keys)
        }
        return currentActivity
    }
}
