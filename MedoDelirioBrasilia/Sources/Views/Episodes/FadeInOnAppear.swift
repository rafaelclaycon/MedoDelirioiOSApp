//
//  FadeInOnAppear.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 03/10/26.
//

import SwiftUI

/// Fades a view in when it appears. Driven by the view itself rather than an animation
/// on its container, so nothing around it animates along.
struct FadeInOnAppear: ViewModifier {

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    isVisible = true
                }
            }
    }
}

extension View {

    func fadeInOnAppear() -> some View {
        modifier(FadeInOnAppear())
    }
}
