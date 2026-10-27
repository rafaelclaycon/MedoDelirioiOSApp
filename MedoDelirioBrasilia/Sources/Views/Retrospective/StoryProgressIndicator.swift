//
//  StoryProgressIndicator.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/11/25.
//

import SwiftUI

/// Shows progress bars for multiple stories at the top of the screen
struct StoryProgressIndicator: View {
    
    let numberOfStories: Int
    let currentStoryIndex: Int
    let currentProgress: CGFloat
    var tint: Color = .white
    
    private let spacing: CGFloat = 4
    private let height: CGFloat = 3
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<numberOfStories, id: \.self) { index in
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        Rectangle()
                            .foregroundStyle(tint.opacity(0.3))
                            .cornerRadius(height / 2)
                        
                        // Progress bar
                        Rectangle()
                            .frame(width: progressWidth(for: index, totalWidth: geometry.size.width))
                            .foregroundStyle(tint.opacity(0.9))
                            .cornerRadius(height / 2)
                            .animation(.linear(duration: 0.1), value: currentProgress)
                    }
                }
                .frame(height: height)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentStoryIndex {
            // Already viewed - full width
            return totalWidth
        } else if index == currentStoryIndex {
            // Currently viewing - partial width based on progress
            return totalWidth * currentProgress
        } else {
            // Not yet viewed - no width
            return 0
        }
    }
}

#Preview {
    VStack {
        StoryProgressIndicator(
            numberOfStories: 6,
            currentStoryIndex: 2,
            currentProgress: 0.5
        )
        .background(.black)
        
        Spacer()
    }
}

