//
//  SidebarLayout.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/09/26.
//

import SwiftUI

extension EnvironmentValues {

    /// Whether `MainView` is showing the sidebar layout (the `.sidebarAdaptable` `TabView`
    /// with Favorites, Authors and Folders as their own tabs) instead of the compact tab bar.
    ///
    /// `MainView` decides this from its own horizontal size class, on iPad only, so it
    /// follows the window: iPad full screen gets the sidebar, while iPad Split View gets the
    /// tab bar. It changes while the app runs. iPhone, including an unfolded iPhone Duo,
    /// always gets the tab bar, because `.sidebarAdaptable` can't draw a sidebar there.
    ///
    /// Read this, not `horizontalSizeClass`, for anything that has to agree with the
    /// navigation `MainView` is showing: where Settings and Search live, which filters the
    /// Sounds tab offers, how Now Playing is presented, and help text describing any of it.
    /// On iPad a sheet reports a compact size class even while the sidebar is showing
    /// behind it, so reading `horizontalSizeClass` inside one gets it wrong.
    @Entry var usesSidebarLayout: Bool = false
}
