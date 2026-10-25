//
//  FakeAppPersistentMemory.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/05/25.
//

import Foundation

final class FakeAppPersistentMemory: AppPersistentMemoryProtocol {

    var customInstallId: String = ""

    var lastUpdateAttempt: String?
    var allowedContentUpdate: Bool = false

    var folderResearchHashValue: [String: String]? = nil
    var hasSentFolderResearchInfo = false
    var lastFolderResearchSyncDateTimeValue: Date? = nil
    var hasDismissedJoinFolderResearchBanner = false

    func hasAllowedContentUpdate() -> Bool {
        allowedContentUpdate
    }

    func hasAllowedContentUpdate(_ newValue: Bool) {
        allowedContentUpdate = newValue
    }

    func setLastUpdateAttempt(to newValue: String) {
        lastUpdateAttempt = newValue
    }
    
    private var internalRecentSearches: [String] = []

    func folderResearchHashes() -> [String : String]? {
        return folderResearchHashValue
    }
    
    func folderResearchHashes(_ hashes: [String : String]) {
        folderResearchHashValue = hashes
    }
    
    func getHasSentFolderResearchInfo() -> Bool {
        return hasSentFolderResearchInfo
    }
    
    func setHasSentFolderResearchInfo(to newValue: Bool) {
        hasSentFolderResearchInfo = newValue
    }
    
    func getHasDismissedJoinFolderResearchBanner() -> Bool? {
        hasDismissedJoinFolderResearchBanner
    }
    
    func lastFolderResearchSyncDateTime() -> Date? {
        lastFolderResearchSyncDateTimeValue
    }
    
    func lastFolderResearchSyncDateTime(_ dateTime: Date) {
        lastFolderResearchSyncDateTimeValue = dateTime
    }
    
    func hasSeenVersion9WhatsNewScreen() -> Bool {
        return false
    }
    
    func hasSeenVersion9WhatsNewScreen(_ newValue: Bool) {
        //
    }

    func saveRecentSearches(_ searchTerms: [String]) {
        internalRecentSearches = searchTerms
    }

    func recentSearches() -> [String]? {
        internalRecentSearches
    }
}
