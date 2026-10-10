//
//  SidebarTabTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 10/10/26.
//

import Testing
@testable import MedoDelirio

struct SidebarTabTests {

    // MARK: - From PhoneTab

    @Test(arguments: [
        (ContentModeOption?.none, SidebarTab.sounds),
        (.all, .sounds),
        (.songs, .sounds),
        (.favorites, .favorites),
        (.folders, .allFolders),
        (.authors, .authors)
    ])
    func phoneSoundsTab_shouldMapEachVirgulasSectionToItsSidebarItem(mode: ContentModeOption?, expected: SidebarTab) {
        #expect(SidebarTab(.sounds, soundsMode: mode) == expected)
    }

    @Test(arguments: [
        (PhoneTab.reactions, SidebarTab.reactions),
        (.episodes, .episodes),
        (.search, .search)
    ])
    func phoneTab_shouldMapToTheMatchingSidebarItem(tab: PhoneTab, expected: SidebarTab) {
        #expect(SidebarTab(tab) == expected)
    }

    @Test
    func phoneSettingsTab_shouldHaveNoSidebarItem() {
        #expect(SidebarTab(.settings) == nil)
    }

    // MARK: - From PadScreen

    @Test(arguments: [
        (PadScreen.allSounds, SidebarTab.sounds),
        (.favorites, .favorites),
        (.groupedByAuthor, .authors),
        (.reactions, .reactions),
        (.trends, .search),
        (.allFolders, .allFolders),
        (.specificFolder, .allFolders)
    ])
    func padScreen_shouldMapToTheMatchingSidebarItem(screen: PadScreen, expected: SidebarTab) {
        #expect(SidebarTab(screen) == expected)
    }

    @Test(arguments: [PadScreen.songs, .settings])
    func padScreen_withoutASidebarItem_shouldMapToNil(screen: PadScreen) {
        #expect(SidebarTab(screen) == nil)
    }
}
