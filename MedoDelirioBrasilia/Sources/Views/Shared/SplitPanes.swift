//
//  SplitPanes.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 01/10/26.
//

import SwiftUI

/// How a screen that can lay out two panes side by side splits them.
enum PaneSplit {

    /// On a display crease running vertically through the screen (unfolded iPhone Duo in
    /// landscape). `ArrangementView`'s `.split` style puts the divider on the crease.
    case crease

    /// Even columns, in an iPad or Mac window wide enough for both panes.
    case columns
}

extension View {

    /// Reports whether this view has room for two panes side by side, and how to split
    /// them: `.crease` where a display crease runs vertically through it, `.columns` in a
    /// wide iPad or Mac window (an iPad in full screen landscape, say), nil otherwise.
    /// Fires again as the view resizes.
    ///
    /// The width check follows the window, so an iPad splits in full screen landscape and
    /// goes back to one column in portrait, Split View or a narrow Stage Manager window.
    /// iPhone is left out: an unfolded iPhone Duo splits on its crease only, not by width.
    func onPaneSplitChange(_ action: @escaping (PaneSplit?) -> Void) -> some View {
        modifier(PaneSplitObserver(action: action))
    }
}

private struct PaneSplitObserver: ViewModifier {

    let action: (PaneSplit?) -> Void

    @State private var hasVerticalCrease: Bool = false
    @State private var isWideWindow: Bool = false

    /// Room for two panes that are each about as wide as an iPhone in portrait, which is
    /// what both panes of every split screen are laid out for.
    private static let minimumColumnsWidth: CGFloat = 720

    private var split: PaneSplit? {
        if hasVerticalCrease {
            return .crease
        }
        return isWideWindow ? .columns : nil
    }

    func body(content: Content) -> some View {
        content
            .onVerticalCreaseChange { hasVerticalCrease = $0 }
            .onGeometryChange(for: Bool.self) { proxy in
                guard UIDevice.deviceType != .iPhone, proxy.size.width >= Self.minimumColumnsWidth else {
                    return false
                }
                // An iPad in portrait keeps one column, where two panes would be tall and
                // narrow. A Mac window's shape is whatever the person dragged it to, so
                // there the width alone decides.
                return ProcessInfo.processInfo.isiOSAppOnMac || proxy.size.width > proxy.size.height
            } action: { isWide in
                isWideWindow = isWide
            }
            .onChange(of: split, initial: true) {
                action(split)
            }
    }
}

/// Two panes side by side, split the way `onPaneSplitChange` reported.
struct SplitPanes<Primary: View, Secondary: View>: View {

    let split: PaneSplit
    let primary: Primary
    let secondary: Secondary

    init(
        _ split: PaneSplit,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.split = split
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        // `ArrangementView` is an iOS 27.1 SDK symbol, so it only compiles with an Xcode
        // that bundles that SDK or later (why this check: see `VerticalCrease.swift`).
        // `.crease` is never reported before 27.1 anyway, since the crease can't be read.
        #if canImport(SwiftUI, _version: 8.0.85.27)
        if split == .crease, #available(iOS 27.1, *) {
            ArrangementView {
                primary
            } secondary: {
                secondary
            }
            .arrangementViewStyle(.split)
        } else {
            columns
        }
        #else
        columns
        #endif
    }

    private var columns: some View {
        HStack(spacing: 0) {
            primary
                .frame(maxWidth: .infinity)

            Divider()

            secondary
                .frame(maxWidth: .infinity)
        }
    }
}
