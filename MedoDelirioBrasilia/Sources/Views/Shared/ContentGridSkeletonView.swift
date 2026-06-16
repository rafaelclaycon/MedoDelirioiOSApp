//
//  ContentGridSkeletonView.swift
//  MedoDelirioBrasilia
//

import SwiftUI

struct ContentGridSkeletonView: View {

    let containerSize: CGSize

    @Environment(\.sizeCategory) private var sizeCategory

    private var spacing: CGFloat { UIDevice.deviceType == .iPhone ? 9 : 14 }

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
            .fill(Color.secondary.opacity(animating ? 0.15 : 0.07))
            .frame(height: itemHeight)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = true }
    }
}

#Preview {
    ContentGridSkeletonView(containerSize: CGSize(width: 390, height: 844))
        .padding(.horizontal, 16)
}
