//
//  View+Marquee.swift
//  MedoDelirioBrasilia
//
//  Created by Kevin Conner on 15/04/2023.
//

import SwiftUI

struct ContentSizeKey: PreferenceKey {
    
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct AvailableWidthKey: PreferenceKey {
    
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum SpeedBasis {
    
    case period(TimeInterval)
    case velocity(CGFloat)
    
    func duration(distance: CGFloat) -> TimeInterval {
        switch self {
        case .period(let seconds):
            return seconds
        case .velocity(let pointsPerSecond):
            return distance / pointsPerSecond
        }
    }
}

struct MarqueeModifier: ViewModifier {
    
    let spacing: CGFloat
    let delay: TimeInterval
    let speedBasis: SpeedBasis
    let fadeWidth: CGFloat
    let centersWhenFitting: Bool

    @State private var contentSize: CGSize?
    @State private var availableWidth: CGFloat?

    @State private var startDate = Date()

    private var isOverflowing: Bool {
        guard let availableWidth, let contentSize else { return false }
        return availableWidth < contentSize.width
    }

    /// When the content fits and centering is requested, this shifts the
    /// leading-aligned scroll content to the middle of the available width.
    /// It's zero while overflowing, so it never interferes with the marquee.
    private var centeringOffset: CGFloat {
        guard centersWhenFitting, !isOverflowing,
              let availableWidth, let contentSize else { return 0 }
        return max((availableWidth - contentSize.width) / 2, 0)
    }
    
    func body(content: Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            scrollingContent(content)
        }
        .scrollDisabled(true)
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: AvailableWidthKey.self, value: geometry.size.width)
            }
        )
        .onPreferenceChange(AvailableWidthKey.self) { value in
            availableWidth = value
        }
        .mask(fadeMask)
    }

    @ViewBuilder
    private func scrollingContent(_ content: Content) -> some View {
        if isOverflowing, let contentSize {
            // Drive the scroll from a per-frame clock rather than a `repeatForever`
            // animation. A perpetual Core Animation living inside a NavigationStack
            // keeps its navigation bar in a continuous animation state and breaks the
            // toolbar (items render blank or misaligned). Computing the offset each
            // frame keeps all the work local to this view, with no implicit animation
            // for the navigation bar to get tangled in.
            let scrollDistance = contentSize.width + spacing
            TimelineView(.animation) { context in
                marqueeStack(content, showsDuplicate: true)
                    .offset(x: offset(at: context.date, scrollDistance: scrollDistance))
            }
        } else {
            marqueeStack(content, showsDuplicate: false)
                .offset(x: centeringOffset)
        }
    }

    private func marqueeStack(_ content: Content, showsDuplicate: Bool) -> some View {
        HStack(spacing: spacing) {
            content
                .fixedSize()
                .overlay(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ContentSizeKey.self, value: geometry.size)
                    }
                )
                .onPreferenceChange(ContentSizeKey.self) { value in
                    contentSize = value
                }

            if showsDuplicate {
                content
                    .fixedSize()
            }
        }
    }

    /// The marquee offset at a given frame time: a `delay` pause at the start of each
    /// loop, then a linear scroll of `scrollDistance` over the speed-based duration.
    /// At the end of the scroll the duplicate copy sits exactly where the original
    /// began, so wrapping back to zero is seamless.
    private func offset(at date: Date, scrollDistance: CGFloat) -> CGFloat {
        let scrollDuration = speedBasis.duration(distance: scrollDistance)
        guard scrollDuration > 0 else { return 0 }
        let cycle = delay + scrollDuration
        let elapsed = date.timeIntervalSince(startDate).truncatingRemainder(dividingBy: cycle)
        guard elapsed > delay else { return 0 }
        let progress = (elapsed - delay) / scrollDuration
        return -scrollDistance * CGFloat(progress)
    }
    
    @ViewBuilder
    private var fadeMask: some View {
        if isOverflowing, fadeWidth > 0 {
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: fadeWidth)
            }
        } else {
            Color.black
        }
    }
}

extension View {
    
    func marquee(
        spacing: CGFloat = 10,
        delay: TimeInterval = 3,
        speedBasis: SpeedBasis = .velocity(50),
        fadeWidth: CGFloat = 8,
        centersWhenFitting: Bool = false
    ) -> some View {
        self.modifier(
            MarqueeModifier(
                spacing: spacing,
                delay: delay,
                speedBasis: speedBasis,
                fadeWidth: fadeWidth,
                centersWhenFitting: centersWhenFitting
            )
        )
    }
}

struct MarqueeModifier_Previews: PreviewProvider {

    static var previews: some View {
        VStack(spacing: 20) {
            Text("Short; usually avoids animating.")
                .padding(5)
                .marquee()
                .background(Color.red.gradient)

            VStack(alignment: .leading) {
                Text("This text pauses at the beginning of each loop of its animation.")
                    .font(.headline)
                Text("iPod 4 life")
                    .font(.subheadline)
            }
            .padding(5)
            .marquee()
            .background(Color.yellow.gradient)

            let interitemSpacing: CGFloat = 20

            HStack(spacing: interitemSpacing) {
                ForEach(["One", "Two", "Three", "Four"], id: \.self) { title in
                    HStack(spacing: 5) {
                        Image(systemName: "music.quarternote.3")
                        Text(title)
                    }
                    .font(.title3.bold())
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .frame(width: 100, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.mint.gradient)
                            .shadow(radius: 2, y: 2)
                    )
                }
            }
            .padding(.horizontal, interitemSpacing)
            .marquee(spacing: -interitemSpacing, delay: 0, speedBasis: .period(2))

        }
        .frame(width: 250, height: 200)
    }
}
