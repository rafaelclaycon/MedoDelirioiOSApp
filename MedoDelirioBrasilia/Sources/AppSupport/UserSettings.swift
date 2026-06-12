//
//  UserSettings.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 23/05/22.
//

import Foundation

protocol UserSettingsProtocol {

    func getShowExplicitContent() -> Bool
    func getHasJoinedFolderResearch() -> Bool

    func authorSortOption(_ newValue: Int)
}

final class UserSettings: UserSettingsProtocol {

    private let userDefaults: UserDefaults

    init(
        userDefaults: UserDefaults = UserDefaults.standard
    ) {
        self.userDefaults = userDefaults
    }
}

// MARK: - Getters

extension UserSettings {

    func getShowExplicitContent() -> Bool {
        guard let value = userDefaults.object(forKey: "showExplicitContent") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func mainSoundListSoundSortOption() -> Int {
        guard let value = userDefaults.object(forKey: "soundSortOption") else {
            return 2
        }
        return Int(value as! Int)
    }

    func getSongSortOption() -> Int {
        guard let value = userDefaults.object(forKey: "songSortOption") else {
            return 1
        }
        return Int(value as! Int)
    }

    func getEnableTrends() -> Bool {
        guard let value = userDefaults.object(forKey: "enableTrends") else {
            return true
        }
        return Bool(value as! Bool)
    }

    func getEnableMostSharedSoundsByTheUser() -> Bool {
        guard let value = userDefaults.object(forKey: "enableMostSharedSoundsByTheUser") else {
            return true
        }
        return Bool(value as! Bool)
    }

    func getEnableDayOfTheWeekTheUserSharesTheMost() -> Bool {
        guard let value = userDefaults.object(forKey: "enableDayOfTheWeekTheUserSharesTheMost") else {
            return true
        }
        return Bool(value as! Bool)
    }

    func getEnableSoundsMostSharedByTheAudience() -> Bool {
        guard let value = userDefaults.object(forKey: "enableSoundsMostSharedByTheAudience") else {
            return true
        }
        return Bool(value as! Bool)
    }

    func getEnableAppsThroughWhichTheUserSharesTheMost() -> Bool {
        guard let value = userDefaults.object(forKey: "enableAppsThroughWhichTheUserSharesTheMost") else {
            return true
        }
        return Bool(value as! Bool)
    }

    func getEnableShareUserPersonalTrends() -> Bool {
        guard let value = userDefaults.object(forKey: "enableShareUserPersonalTrends") else {
            return true
        }
        return Bool(value as! Bool)
    }

    func getUserAllowedNotifications() -> Bool {
        guard let value = userDefaults.object(forKey: "userAllowedNotifications") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getHotWeatherBannerWasDismissed() -> Bool {
        guard let value = userDefaults.object(forKey: "hotWeatherBannerWasDismissed") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getLastSendDateOfStillAliveSignalToServer() -> Date? {
        guard let value = userDefaults.object(forKey: "lastSendDateOfStillAliveSignalToServer") else {
            return nil
        }
        return Date(timeIntervalSince1970: value as! Double)
    }

    func authorSortOption() -> Int {
        guard let value = userDefaults.object(forKey: "authorSortOption") else {
            return 0
        }
        return Int(value as! Int)
    }

    func getHasJoinedFolderResearch() -> Bool {
        guard let value = userDefaults.object(forKey: "hasJoinedFolderResearch") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getEnableEpisodeNotifications() -> Bool {
        guard let value = userDefaults.object(forKey: "enableEpisodeNotifications") else {
            return false
        }
        return Bool(value as! Bool)
    }

    func getAutoDeletePlayedEpisodes() -> Bool {
        guard let value = userDefaults.object(forKey: "autoDeletePlayedEpisodes") else {
            return true
        }
        return Bool(value as! Bool)
    }

    func getWeeklyHighlightsOptedOut() -> Bool {
        guard let value = userDefaults.object(forKey: "weeklyHighlightsOptedOut") else {
            return false
        }
        return Bool(value as! Bool)
    }
}

// MARK: - Setters

extension UserSettings {

    func setShowExplicitContent(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "showExplicitContent")
    }
    
    func saveMainSoundListSoundSortOption(_ newValue: Int) {
        userDefaults.set(newValue, forKey: "soundSortOption")
    }
    
    func setSongSortOption(to newValue: Int) {
        userDefaults.set(newValue, forKey: "songSortOption")
    }
    
    func setEnableTrends(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "enableTrends")
    }
    
    func setEnableMostSharedSoundsByTheUser(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "enableMostSharedSoundsByTheUser")
    }
    
    func setEnableDayOfTheWeekTheUserSharesTheMost(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "enableDayOfTheWeekTheUserSharesTheMost")
    }
    
    func setEnableSoundsMostSharedByTheAudience(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "enableSoundsMostSharedByTheAudience")
    }
    
    func setEnableAppsThroughWhichTheUserSharesTheMost(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "enableAppsThroughWhichTheUserSharesTheMost")
    }
    
    func setEnableShareUserPersonalTrends(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "enableShareUserPersonalTrends")
    }
    
    func setUserAllowedNotifications(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "userAllowedNotifications")
    }
    
    func setHotWeatherBannerWasDismissed(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hotWeatherBannerWasDismissed")
    }
    
    func setLastSendDateOfStillAliveSignalToServer(to newValue: Date) {
        userDefaults.set(newValue.timeIntervalSince1970, forKey: "lastSendDateOfStillAliveSignalToServer")
    }

    func authorSortOption(_ newValue: Int) {
        userDefaults.set(newValue, forKey: "authorSortOption")
    }

    func setHasJoinedFolderResearch(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "hasJoinedFolderResearch")
    }

    func setEnableEpisodeNotifications(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "enableEpisodeNotifications")
    }

    func setAutoDeletePlayedEpisodes(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "autoDeletePlayedEpisodes")
    }

    func setWeeklyHighlightsOptedOut(to newValue: Bool) {
        userDefaults.set(newValue, forKey: "weeklyHighlightsOptedOut")
    }
}
