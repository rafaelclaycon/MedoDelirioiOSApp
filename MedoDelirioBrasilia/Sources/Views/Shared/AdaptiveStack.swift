//
//  AdaptiveStack.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 16/06/26.
//

import SwiftUI

/// A stack that arranges its content vertically when there is regular vertical
/// space, and horizontally when vertical space is compact (e.g. iPhone landscape).
///
/// Uses `AnyLayout` so view identity is preserved across the layout switch — child
/// state and in-flight animations survive a rotation instead of being rebuilt.
///
/// By default the size class is read from the environment, so the stack adapts on
/// its own. Pass an explicit `isCompact` to drive it from a parent that already
/// tracks the size class (e.g. `NowPlayingView`'s `vSizeClass`).
struct AdaptiveStack<Content: View>: View {

    private let horizontalAlignment: HorizontalAlignment
    private let verticalAlignment: VerticalAlignment
    private let spacing: CGFloat?
    private let isCompactOverride: Bool?
    @ViewBuilder private let content: () -> Content

    @Environment(\.verticalSizeClass) private var vSizeClass

    /// - Parameters:
    ///   - isCompact: When provided, forces the compact (horizontal) layout on/off
    ///     instead of reading `verticalSizeClass`. Pass `nil` to adapt automatically.
    ///   - horizontalAlignment: Alignment used in the vertical (regular) layout.
    ///   - verticalAlignment: Alignment used in the horizontal (compact) layout.
    ///   - spacing: Spacing between items in whichever axis is active.
    init(
        isCompact: Bool? = nil,
        horizontalAlignment: HorizontalAlignment = .center,
        verticalAlignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isCompactOverride = isCompact
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.spacing = spacing
        self.content = content
    }

    private var isCompact: Bool {
        isCompactOverride ?? (vSizeClass == .compact)
    }

    var body: some View {
        let layout = isCompact
            ? AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
            : AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))

        layout {
            content()
        }
    }
}
