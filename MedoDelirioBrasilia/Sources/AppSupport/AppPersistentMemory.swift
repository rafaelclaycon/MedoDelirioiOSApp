//
//  AppPersistentMemory.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/08/22.
//

import Foundation

protocol AppPersistentMemoryProtocol {

    func hasAllowedContentUpdate() -> Bool
    func hasAllowedContentUpdate(_ newValue: Bool)
    func setLastUpdateAttempt(to newValue: String)

    func folderResearchHashes() -> [String: String]?
    func folderResearchHashes(_ foldersHashes: [String: String])

    /// This was used to mark sending before the more elaborate change syncing.
    func getHasSentFolderResearchInfo() -> Bool
    func setHasSentFolderResearchInfo(to newValue: Bool)
    func getHasDismissedJoinFolderResearchBanner() -> Bool?

    func lastFolderResearchSyncDateTime() -> Date?
    func lastFolderResearchSyncDateTime(_ dateTime: Date)

    func hasSeenVersion9WhatsNewScreen() -> Bool
    func hasSeenVersion9WhatsNewScreen(_ newValue: Bool)

    func hasSeenUniversalSearchWhatsNewScreen() -> Bool
    func hasSeenUniversalSearchWhatsNewScreen(_ newValue: Bool)

    func hasSeenTranscriptsWhatsNewScreen() -> Bool
    func hasSeenTranscriptsWhatsNewScreen(_ newValue: Bool)

    var customInstallId: String { get }

    func saveRecentSearches(_ searchTerms: [String])
    func recentSearches() -> [String]?
}

/// Different from User Settings, App Memory are settings that help the app remember stuff to avoid asking again or doing a network job more than once per day.
final class AppPersistentMemory: AppPersistentMemoryProtocol {

    private let userDefaults: UserDefaults

    static let shared = AppPersistentMemory()

    init(
        userDefaults: UserDefaults = UserDefaults.standard
    ) {
        self.userDefaults = userDefaults
    }
}

// MARK: - Getters

extension AppPersistentMemory {

    var customInstallId: String {
        guard let existingCustomDeviceID = userDefaults.object(forKey: "customInstallId") else {
            let newlyCreatedDeviceID = UUID().uuidString
            userDefaults.set(newlyCreatedDeviceID, forKey: "customInstallId")
            return newlyCreatedDeviceID
        }
        return String(existingCustomDeviceID as! String)
    }

    func getHasSentDeviceModelToServer() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSentDeviceModelToServer") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getLastSendDateOfUserPersonalTrendsToServer() -> Date? {
        guard let value = userDefaults.object(forKey: "lastSendDateOfUserPersonalTrendsToServer") else {
            return nil
        }
        return Date(timeIntervalSince1970: value as! Double)
    }

    func getFolderBannerWasDismissed() -> Bool {
        guard let value = userDefaults.object(forKey: "folderBannerWasDismissed") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getLastSentPushToken() -> String? {
        guard let value = userDefaults.object(forKey: "lastSentPushToken") else {
            return nil
        }
        return String(value as! String)
    }

    func hasShownNotificationsOnboarding() -> Bool {
        guard let value = userDefaults.object(forKey: "hasShownNotificationsOnboarding") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getHasHiddenShareAsVideoTextSocialNetworkTip() -> Bool {
        guard let value = userDefaults.object(forKey: "hasHiddenShareAsVideoTwitterTip") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getHasHiddenShareAsVideoInstagramTip() -> Bool {
        guard let value = userDefaults.object(forKey: "hasHiddenShareAsVideoInstagramTip") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getHasDismissedJoinFolderResearchBanner() -> Bool? {
        guard let value = userDefaults.object(forKey: "hasDismissedJoinFolderResearchBanner") else {
            return nil
        }
        return Bool(value as! Bool)
    }

    func getHasSentFolderResearchInfo() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSentFolderResearchInfo") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func hasSeenReactionsWhatsNewScreen() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenReactionsWhatsNewScreen") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func hasSeenControlWhatsNewScreen() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenControlWhatsNewScreen") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getHasSeenBetaBanner() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenBetaBanner") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getHasSeenBetaSurveyBanner() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenBetaSurveyBanner") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getShareManyMessageShowCount() -> Int {
        guard let value = userDefaults.object(forKey: "shareManyMessageShowCount") else {
            return 0
        }
        return Int(value as! Int)
    }

    func getLastUpdateAttempt() -> String {
        guard let value = userDefaults.object(forKey: "lastUpdateAttempt") else {
            return ""
        }
        return String(value as! String)
    }

    func folderResearchHashes() -> [String: String]? {
        guard let value = userDefaults.object(forKey: "folderResearchHash") else {
            return nil
        }
        return value as? [String: String]
    }

    func lastFolderResearchSyncDateTime() -> Date? {
        guard let value = userDefaults.object(forKey: "lastFolderResearchSyncDateTime") else {
            return nil
        }
        return Date(timeIntervalSince1970: value as! Double)
    }

    func hasSeenPinReactionsBanner() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenPinReactionsBanner") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func hasDismissedDunBanner() -> Bool {
        guard let value = userDefaults.object(forKey: "hasDismissedDunBanner") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getHasDismissedEpisodeNotificationsBanner() -> Bool {
        guard let value = userDefaults.object(forKey: "hasDismissedEpisodeNotificationsBanner") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func hasSeenVersion9WhatsNewScreen() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenVersion9WhatsNewScreen") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func hasSeenUniversalSearchWhatsNewScreen() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenUniversalSearchWhatsNewScreen") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func hasSeenTranscriptsWhatsNewScreen() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenTranscriptsWhatsNewScreen") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func recentSearches() -> [String]? {
        guard let value = userDefaults.stringArray(forKey: "recentSearches") else {
            return nil
        }
        return value
    }

    func hasAllowedContentUpdate() -> Bool {
        userDefaults.bool(forKey: "hasAllowedContentUpdate")
    }

    // MARK: Episode Support Prompt

    func getEpisodesCompletedCount() -> Int {
        guard let value = userDefaults.object(forKey: "episodesCompletedCount") else {
            return 0
        }
        return value as! Int
    }

    func getHasSeenEpisodeSupportPrompt() -> Bool {
        guard let value = userDefaults.object(forKey: "hasSeenEpisodeSupportPrompt") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getLastSupportPromptDate() -> Date? {
        guard let value = userDefaults.object(forKey: "lastSupportPromptDate") else {
            return nil
        }
        return Date(timeIntervalSince1970: value as! Double)
    }

    func shouldShowEpisodeSupportPrompt() -> Bool {
        guard !getHasSeenEpisodeSupportPrompt() else { return false }
        guard getEpisodesCompletedCount() >= 3 else { return false }
        if let lastDate = getLastSupportPromptDate(),
           Date().timeIntervalSince(lastDate) < 7 * 24 * 3600 {
            return false
        }
        return true
    }

    // MARK: Episodes Tab Badge

    func getEpisodesTabLastVisitedAt() -> Date? {
        guard let value = userDefaults.object(forKey: "episodesTabLastVisitedAt") else {
            return nil
        }
        return Date(timeIntervalSince1970: value as! Double)
    }
}

// MARK: - Setters

extension AppPersistentMemory {

    func setHasSentDeviceModelToServer(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSentDeviceModelToServer")
    }
    
    func setLastSendDateOfUserPersonalTrendsToServer(to newValue: Date) {
        userDefaults.set(newValue.timeIntervalSince1970, forKey: "lastSendDateOfUserPersonalTrendsToServer")
    }
    
    func setFolderBannerWasDismissed(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "folderBannerWasDismissed")
    }
    
    func setLastSentPushToken(to token: String) {
        userDefaults.set(token, forKey: "lastSentPushToken")
    }

    func clearLastSentPushToken() {
        userDefaults.removeObject(forKey: "lastSentPushToken")
    }
    
    func hasShownNotificationsOnboarding(_ newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasShownNotificationsOnboarding")
    }
    
    func setHasHiddenShareAsVideoTextSocialNetworkTip(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasHiddenShareAsVideoTwitterTip")
    }
    
    func setHasHiddenShareAsVideoInstagramTip(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasHiddenShareAsVideoInstagramTip")
    }
    
    func setHasDismissedJoinFolderResearchBanner(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasDismissedJoinFolderResearchBanner")
    }
    
    func setHasSentFolderResearchInfo(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSentFolderResearchInfo")
    }

    func hasSeenReactionsWhatsNewScreen(_ newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenReactionsWhatsNewScreen")
    }

    func hasSeenControlWhatsNewScreen(_ newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenControlWhatsNewScreen")
    }

    func setHasSeenBetaBanner(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenBetaBanner")
    }

    func setHasSeenBetaSurveyBanner(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenBetaSurveyBanner")
    }

    func increaseShareManyMessageShowCountByOne() {
        let currentCount = getShareManyMessageShowCount()
        userDefaults.set(currentCount + 1, forKey: "shareManyMessageShowCount")
    }

    func setLastUpdateAttempt(to newValue: String) {
        userDefaults.set(newValue, forKey: "lastUpdateAttempt")
    }

    func folderResearchHashes(_ foldersHashes: [String: String]) {
        userDefaults.set(foldersHashes, forKey: "folderResearchHash")
    }

    func lastFolderResearchSyncDateTime(_ dateTime: Date) {
        userDefaults.set(dateTime.timeIntervalSince1970, forKey: "lastFolderResearchSyncDateTime")
    }

    func setHasSeenPinReactionsBanner(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenPinReactionsBanner")
    }

    func setHasDismissedDunBanner(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasDismissedDunBanner")
    }

    func setHasDismissedEpisodeNotificationsBanner(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasDismissedEpisodeNotificationsBanner")
    }

    func hasSeenVersion9WhatsNewScreen(_ newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenVersion9WhatsNewScreen")
    }

    func hasSeenUniversalSearchWhatsNewScreen(_ newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenUniversalSearchWhatsNewScreen")
    }

    func hasSeenTranscriptsWhatsNewScreen(_ newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenTranscriptsWhatsNewScreen")
    }

    func saveRecentSearches(_ searchTerms: [String]) {
        userDefaults.set(searchTerms, forKey: "recentSearches")
    }

    func hasAllowedContentUpdate(_ newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasAllowedContentUpdate")
    }

    // MARK: Episode Support Prompt

    func setEpisodesCompletedCount(_ newValue: Int) {
        userDefaults.set(newValue, forKey: "episodesCompletedCount")
    }

    func setHasSeenEpisodeSupportPrompt(_ newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasSeenEpisodeSupportPrompt")
    }

    func setLastSupportPromptDate(_ newValue: Date) {
        userDefaults.set(newValue.timeIntervalSince1970, forKey: "lastSupportPromptDate")
    }

    // MARK: Episodes Tab Badge

    func setEpisodesTabLastVisitedAt(_ newValue: Date) {
        userDefaults.set(newValue.timeIntervalSince1970, forKey: "episodesTabLastVisitedAt")
    }
}
