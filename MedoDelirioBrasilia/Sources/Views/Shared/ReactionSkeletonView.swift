//
//  ReactionSkeletonView.swift
//  MedoDelirioBrasilia
//

import SwiftUI

/// Pulsing placeholder shaped like a `ReactionItem`, shown while reactions load.
///
/// Matches the reaction-card geometry (`cornerRadius: 20`, height `100`/`120`)
/// with a centered title placeholder. Shared between the search suggestions and
/// the Reactions tab so both loading states look identical.
struct ReactionSkeletonView: View {

    @State private var isAnimating = false

    private var itemHeight: CGFloat {
        UIDevice.deviceType == .iPhone ? 100 : 120
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.gray.opacity(0.2))
            .frame(height: itemHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 20)
            }
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

#Preview {
    ReactionSkeletonView()
        .padding()
}
