//
//  DeepLinkHandler.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/05/26.
//

import Foundation

enum DeepLink: Equatable {
    case reaction(id: String)
    case episode(id: String)
}

/// Carries a pending deep-link from the App entry point down to MainView,
/// which owns the NavigationPaths needed to perform the actual push.
@Observable
final class DeepLinkHandler {
    var pendingDeepLink: DeepLink?
}
