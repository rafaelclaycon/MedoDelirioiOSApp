//
//  TrendsHelper.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 14/12/22.
//

import SwiftUI

/// Class that allows the communication between `TrendsView` and other tabs.
///
/// - Parameters:
///    - contentIdToNavigateTo: Tells `MainContentView` what content ID to scroll to.
@Observable class TrendsHelper {

    // To Sounds tab
    var contentIdToNavigateTo: String = ""

    // To Songs tab
    var songIdToNavigateTo: String = ""

    // To Reactions tab
    var reactionIdToNavigateTo: String = ""

    // From Siri Suggestions
    var timeIntervalToGoTo: TrendsTimeInterval? = nil
    var refreshMostSharedByAudienceList: Bool = false

    /// Tells `MainContentView` which sub-mode to switch to (Favorites, Folders, Authors)
    /// when the user taps a Siri Suggestion. On iPhone these live as modes inside the Sounds tab.
    var contentModeToGoTo: ContentModeOption? = nil
}
