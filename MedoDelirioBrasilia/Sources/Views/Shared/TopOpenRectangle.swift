//
//  TopOpenRectangle.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/05/26.
//

import SwiftUI

/// A rectangle clip shape that is open at the top — content can render far
/// above the view's bounds (so a stretchy header image can fill the overscroll
/// gap), while still clipping anything below the bottom edge.
///
/// Used by detail headers that grow their background image when the user pulls
/// the scroll view down. A plain `.clipped()` would clip the upward expansion
/// and reintroduce the empty/white area at the top on overscroll.
struct TopOpenRectangle: Shape {

    /// How far above the view's bounds the clip region extends.
    var topExtension: CGFloat = 10_000

    func path(in rect: CGRect) -> Path {
        Path(
            CGRect(
                x: rect.minX,
                y: rect.minY - topExtension,
                width: rect.width,
                height: rect.height + topExtension
            )
        )
    }
}
