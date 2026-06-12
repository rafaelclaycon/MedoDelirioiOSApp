import StoreKit
import UIKit

class AppStoreReviewSteward {

    static func requestReviewBasedOnVersionAndCount() {
        var count = UserDefaults.standard.integer(forKey: UserDefaultsKeys.processCompletedCountKey)
        count += 1
        UserDefaults.standard.set(count, forKey: UserDefaultsKeys.processCompletedCountKey)

        //print("Process completed \(count) time(s)")

        let infoDictionaryKey = kCFBundleVersionKey as String
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String else {
            fatalError("Expected to find a bundle version in the info dictionary")
        }

        let lastVersionPromptedForReview = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey)

        if count >= 4 && currentVersion != lastVersionPromptedForReview {
            Task { @MainActor in
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    AppStore.requestReview(in: scene)
                }
                UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey)
            }
        }
    }
}
