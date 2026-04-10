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
    
    @State private var contentSize: CGSize?
    @State private var availableWidth: CGFloat?
    
    @State private var offset: CGFloat = 0
    
    private var isOverflowing: Bool {
        guard let availableWidth, let contentSize else { return false }
        return availableWidth < contentSize.width
    }
    
    func body(content: Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
                
                if let availableWidth, let contentSize, availableWidth < contentSize.width {
                    content
                        .fixedSize()
                        .onAppear {
                            withAnimation(
                                Animation.linear(duration: speedBasis.duration(distance: contentSize.width + spacing))
                                    .delay(delay)
                                    .repeatForever(autoreverses: false)
                            ) {
                                offset = -(contentSize.width + spacing)
                            }
                        }
                        .onDisappear {
                            withAnimation(.linear(duration: 0)) {
                                offset = 0
                            }
                        }
                }
            }
            .offset(x: offset)
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
        fadeWidth: CGFloat = 8
    ) -> some View {
        self.modifier(
            MarqueeModifier(
                spacing: spacing,
                delay: delay,
                speedBasis: speedBasis,
                fadeWidth: fadeWidth
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
