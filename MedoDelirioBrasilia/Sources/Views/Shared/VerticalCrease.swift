//
//  VerticalCrease.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/09/26.
//

import SwiftUI

extension View {

    /// Reports whether a display crease — a `.division` reserved region — runs vertically
    /// through this view, as on an unfolded iPhone Duo held in landscape. Fires again as
    /// the view resizes (folding, unfolding, rotating). Always false before iOS 27.1.
    ///
    /// Inactive creases count too: the region is only active while the device is partly
    /// folded, and a layout split on the crease suits it lying fully open just as well.
    /// Regions outside this view's bounds don't count.
    ///
    /// Pair it with `ArrangementView` and `.arrangementViewStyle(.split)`, which puts its
    /// divider on that crease by itself.
    func onVerticalCreaseChange(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(VerticalCreaseObserver(action: action))
    }
}

private struct VerticalCreaseObserver: ViewModifier {

    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        // Reserved regions are an iOS 27.1 SDK symbol, so they only compile with the Xcode
        // that bundles that SDK (same guard as `MainView`).
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            content
                .onGeometryChange(for: Bool.self) { proxy in
                    let bounds = CGRect(origin: .zero, size: proxy.size)
                    return proxy.reservedRegions(kind: .division, options: .includeInactive).contains { region in
                        region.frame.height > region.frame.width && region.frame.intersects(bounds)
                    }
                } action: { hasVerticalCrease in
                    action(hasVerticalCrease)
                }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
