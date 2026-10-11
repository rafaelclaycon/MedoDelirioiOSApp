//
//  ContentGridSkeletonView.swift
//  MedoDelirioBrasilia
//

import SwiftUI

struct ContentGridSkeletonView: View {

    let containerSize: CGSize

    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var spacing: CGFloat { hSizeClass != .regular ? 9 : 14 }

    private var columns: [GridItem] {
        GridHelper.adaptableColumns(
            gridWidth: containerSize.width,
            sizeCategory: sizeCategory,
            spacing: spacing
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(0..<12, id: \.self) { _ in
                SkeletonContentTile()
            }
        }
    }
}

private struct SkeletonContentTile: View {

    @State private var animating = false

    private let itemHeight: CGFloat = 100

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .frame(height: itemHeight)
            // Pulses between 0.07 and 0.15, like the fill used to. Scoped to the opacity
            // so the tile's own move while the screen lays out isn't repeated forever.
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) { content in
                content.opacity(animating ? 1 : 0.07 / 0.15)
            }
            .onAppear { animating = true }
    }
}

#Preview {
    ContentGridSkeletonView(containerSize: CGSize(width: 390, height: 844))
        .padding(.horizontal, 16)
}
