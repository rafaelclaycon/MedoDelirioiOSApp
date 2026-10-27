//
//  Story.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/11/25.
//

import SwiftUI

/// Represents a single story in the retrospective stories flow
struct Story: Identifiable, Equatable {
    let id: String
    let duration: TimeInterval
    let backgroundColor: StoryBackgroundStyle
    
    init(
        id: String,
        duration: TimeInterval = 5.0,
        backgroundColor: StoryBackgroundStyle = .solid(.black)
    ) {
        self.id = id
        self.duration = duration
        self.backgroundColor = backgroundColor
    }
    
    static func == (lhs: Story, rhs: Story) -> Bool {
        lhs.id == rhs.id
    }
}

/// Background style options for stories
enum StoryBackgroundStyle {
    case solid(Color)
    case gradient(Gradient, startPoint: UnitPoint, endPoint: UnitPoint)
    
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .solid(let color):
            color
        case .gradient(let gradient, let startPoint, let endPoint):
            LinearGradient(
                gradient: gradient,
                startPoint: startPoint,
                endPoint: endPoint
            )
        }
    }
}

/// The pages of the Retrospectiva, each in its own flat color.
enum StoryPage: String, CaseIterable {
    case intro
    case shares
    case topAuthor
    case topSound1
    case topSound2
    case topSound3
    case listening
    case topEpisode
    case habits
    case share

    /// Pages to read get a little longer than pages to look at.
    var story: Story {
        switch self {
        case .intro: Story(id: rawValue, duration: 4.0, backgroundColor: .solid(.black))
        case .shares: Story(id: rawValue, duration: 6.0, backgroundColor: .solid(RetroPalette.red))
        case .topAuthor: Story(id: rawValue, duration: 6.0, backgroundColor: .solid(RetroPalette.deepRed))
        case .topSound3: Story(id: rawValue, duration: 6.0, backgroundColor: .solid(RetroPalette.wine))
        case .topSound2: Story(id: rawValue, duration: 6.0, backgroundColor: .solid(RetroPalette.deepRed))
        case .topSound1: Story(id: rawValue, duration: 7.0, backgroundColor: .solid(RetroPalette.cream))
        case .listening: Story(id: rawValue, duration: 6.0, backgroundColor: .solid(RetroPalette.wine))
        case .topEpisode: Story(id: rawValue, duration: 6.0, backgroundColor: .solid(.black))
        case .habits: Story(id: rawValue, duration: 6.0, backgroundColor: .solid(RetroPalette.red))
        case .share:
            Story(
                id: rawValue,
                duration: 10.0,
                backgroundColor: .gradient(
                    Gradient(colors: [RetroPalette.shareTop, RetroPalette.shareBottom]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    /// The cream page, where the bars and buttons on top go dark.
    var isLight: Bool {
        self == .topSound1
    }

    /// The Vírgula a countdown page is about, 0 for the number one.
    var topSoundIndex: Int? {
        switch self {
        case .topSound1: 0
        case .topSound2: 1
        case .topSound3: 2
        default: nil
        }
    }
}
