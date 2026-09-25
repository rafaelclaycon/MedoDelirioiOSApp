//
//  ToolbarVerticalEdge.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/09/26.
//

import SwiftUI

extension View {

    /// Reports which edge the system moved the toolbar to when it shows it as a vertical
    /// bar (iPhone Duo, some landscape layouts): `.leading`, `.trailing`, or nil where the
    /// toolbar stays horizontal. Always nil before iOS 27.1.
    ///
    /// `toolbarVerticalEdge` can't back a stored `@Environment` property in a view that
    /// also runs before 27.1, hence this wrapper.
    func onToolbarVerticalEdgeChange(_ action: @escaping (HorizontalEdge?) -> Void) -> some View {
        modifier(ToolbarVerticalEdgeObserver(action: action))
    }
}

private struct ToolbarVerticalEdgeObserver: ViewModifier {

    let action: (HorizontalEdge?) -> Void

    func body(content: Content) -> some View {
        // `toolbarVerticalEdge` is an iOS 27.1 SDK symbol, so it only compiles with the
        // Xcode that bundles that SDK (same guard as `MainView`).
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            content.modifier(Reader(action: action))
        } else {
            content
        }
        #else
        content
        #endif
    }

    #if compiler(>=6.4)
    @available(iOS 27.1, *)
    private struct Reader: ViewModifier {

        let action: (HorizontalEdge?) -> Void

        @Environment(\.toolbarVerticalEdge) private var edge

        func body(content: Content) -> some View {
            content
                .onChange(of: edge, initial: true) {
                    action(edge)
                }
        }
    }
    #endif
}
