//
//  ModernContentViews.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 03/06/26.
//

import SwiftUI

private let shapeCornerRadius: CGFloat = 18

// MARK: - Reusable Views

struct ModernContent {

    private struct MainText: View {

        let title: String
        let subtitle: String
        var duration: Double?
        let color: Color
        let isSong: Bool
        let isPlaying: Bool

        @Environment(\.colorScheme) private var colorScheme

        private var lowerPartColor: Color {
            colorScheme == .dark ? color : color.darkened(by: 0.5)
        }

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: .spacing(.small)) {
                    Text(title)
                        .fontDesign(.rounded)
                        .font(.body)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        if isSong {
                            Image(systemName: "music.quarternote.3")
                                .foregroundStyle(lowerPartColor)
                                .symbolEffect(.bounce.up.byLayer, options: .repeat(.continuous), isActive: isPlaying)
                        }

                        Group {
                            Text(subtitle.uppercased())

                            if let duration {
                                Text(isPlaying ? duration.minuteSecondFormatted : duration.minuteSecondFormattedPretty)
                            }
                        }
                        .fontDesign(.monospaced)
                        .foregroundStyle(lowerPartColor)
                        .font(.caption)
                        .bold()
                        .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.leading, .spacing(.medium))
        }
    }

    private struct SimplestBackground: View {

        let color: Color
        let cornerRadius: CGFloat
        let isFavorite: Bool
        var isSelected: Bool = false

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    colorScheme == .dark ?
                    color.opacity(0.33) : color.darkened(by: 0.3).opacity(0.2)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            isSelected ? .blue : isFavorite ? Color.red.opacity(0.7) : color.opacity(colorScheme == .dark ? 1 : 0.7),
                            lineWidth: isSelected ? 3 : isFavorite ? 2 : 1
                        )
                }
        }
    }

    private struct FavoriteOverlay: View {
        var body: some View {
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .foregroundColor(.red)
                .padding(.trailing, .spacing(.xSmall))
                .padding(.bottom, .spacing(.xSmall))
        }
    }
}

// MARK: - Specific Views

extension ModernContent {

    /// The main incarnation of sounds and songs in the app.
    struct Button: View {

        let content: any MedoContentProtocol

        var showNewTag: Bool = true
        let favorites: Set<String>
        let highlighted: Set<String>
        let nowPlaying: Set<String>
        let selectedItems: Set<String>
        @Binding var currentContentListMode: ContentGridMode // This needs to be a Binding to keep Selection working.

        @State private var timeRemaining: Double = 0

        @Environment(\.colorScheme) private var colorScheme

        enum Background {
            case regular, favorite, highlighted
        }

        enum Mode {
            case regular, playing, upForSelection, selected
        }

        // MARK: - Computed Properties

        private var currentMode: Mode {
            if currentContentListMode == .selection {
                return selectedItems.contains(content.id) ? .selected : .upForSelection
            } else {
                return nowPlaying.contains(content.id) ? .playing : .regular
            }
        }

        private var background: Background {
            guard highlighted.contains(content.id) == false else {
                return .highlighted
            }
            if favorites.contains(content.id) {
                return .favorite
            } else {
                return .regular
            }
        }

        private var backgroundOpacity: Double {
            switch currentMode {
            case .regular:
                return 1.0
            case .playing:
                return 0.7
            case .upForSelection:
                return 0.7
            case .selected:
                return 1.0
            }
        }

        private var itemHeight: CGFloat {
            if UIDevice.isiPhone {
                return 100
            } else {
                return UIDevice.isiPadMini ? 116 : 100
            }
        }

        private var subtitle: String {
            if currentMode == .playing {
                return timeRemaining.minuteSecondFormatted
            } else {
                return content.subtitle
            }
        }

        private var isNew: Bool {
            guard showNewTag else { return false }
            return Date.isDateWithinLast7Days(content.dateAdded)
        }

        // MARK: - Static Properties

        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        private let unselectedForegroundColor: Color = .gray
        private let favoriteGradient = LinearGradient(gradient: Gradient(colors: [.red]), startPoint: .topLeading, endPoint: .bottomTrailing)
        private let highlightGradient = LinearGradient(gradient: Gradient(colors: [.yellow]), startPoint: .topLeading, endPoint: .bottomTrailing)

        // MARK: - View Body

        var body: some View {
            ZStack {
                Group {
                    switch background {
                    case .regular, .favorite:
                        SimplestBackground(
                            color: content.primaryColor,
                            cornerRadius: shapeCornerRadius,
                            isFavorite: favorites.contains(content.id),
                            isSelected: currentMode == .selected
                        )
                    case .highlighted:
                        RoundedRectangle(cornerRadius: shapeCornerRadius, style: .continuous)
                            .fill(highlightGradient)
                            .opacity(backgroundOpacity)
                    }
                }
                .frame(height: itemHeight)

                MainText(
                    title: content.title,
                    subtitle: subtitle,
                    color: content.primaryColor,
                    isSong: content.type == .song,
                    isPlaying: currentMode == .playing
                )
                .onReceive(timer) { time in
                    guard currentMode == .playing else { return }
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                    }
                }

                if isNew, background == .regular, currentMode == .regular {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(.yellow)
                                    .frame(width: 50, height: 20)

                                Text("NOVO")
                                    .foregroundColor(.black)
                                    .font(.footnote)
                                    .bold()
                                    .opacity(0.7)
                            }
                            .padding(.trailing, 10)
                            .padding(.bottom, 10)
                        }
                    }
                    .frame(height: itemHeight)
                }

                if currentMode == .upForSelection {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            RoundCheckbox(
                                selected: .constant(false),
                                color: content.primaryColor
                            )
                            .padding(.trailing, 10)
                            .padding(.bottom, 10)
                        }
                    }
                    .frame(height: itemHeight)
                } else if currentMode == .selected {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            RoundCheckbox(
                                selected: .constant(true),
                                color: content.primaryColor
                            )
                            .padding(.trailing, 10)
                            .padding(.bottom, 10)
                        }
                    }
                    .frame(height: itemHeight)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if background == .favorite, currentMode == .regular {
                    FavoriteOverlay()
                }
            }
            .overlay {
                if currentMode == .playing {
                    // Inner shadow: dark top edge fading to clear, with a faint
                    // bottom highlight — the classic physical "pressed button" look.
                    RoundedRectangle(cornerRadius: shapeCornerRadius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [
                                Color.black.opacity(0.28),
                                Color.clear,
                                Color.white.opacity(0.07)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if background == .highlighted {
                    HighlightRingEffect(cornerRadius: shapeCornerRadius)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(currentMode == .playing ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentMode == .playing)
            .onAppear {
                if currentMode != .playing {
                    timeRemaining = content.duration
                }
            }
            .onChange(of: currentMode) {
                if currentMode != .playing {
                    timeRemaining = content.duration
                }
            }
        }

    }

    /// A preview shown when a user holds on a content for a couple of seconds to see more options.
    /// It is more complete than the regular content view.
    struct MenuPreview: View {

        let content: any MedoContentProtocol
        let isFavorite: Bool

        var body: some View {
            MainText(
                title: content.title,
                subtitle: content.subtitle,
                duration: content.duration,
                color: content.primaryColor,
                isSong: content.type == .song,
                isPlaying: false
            )
            .frame(width: 300)
            .padding(.vertical, .spacing(.xLarge))
            .background {
                SimplestBackground(
                    color: content.primaryColor,
                    cornerRadius: shapeCornerRadius,
                    isFavorite: isFavorite
                )
            }
            .overlay(alignment: .bottomTrailing) {
                if isFavorite {
                    FavoriteOverlay()
                }
            }
        }
    }

    /// A view that intends to show off this content.
    /// Used for the Get Info context menu option.
    struct ShowOff: View {

        let content: any MedoContentProtocol
        let isPlaying: Bool
        let playAction: () -> Void

        @State private var samples: [Float] = []

        private static let barWidth: CGFloat = 3
        private static let barSpacing: CGFloat = 2
        private static let step: CGFloat = barWidth + barSpacing
        private static let waveHeight: CGFloat = 80

        var body: some View {
            VStack(spacing: .spacing(.large)) {
                Group {
                    if isPlaying {
                        TimelineView(.animation) { timeline in
                            waveCanvas(phase: timeline.date.timeIntervalSinceReferenceDate)
                        }
                    } else {
                        waveCanvas(phase: 0)
                    }
                }
                .frame(height: Self.waveHeight)

                GlassButton(symbol: "play.fill", title: "Tocar", color: .black) {
                    playAction()
                }
            }
            .task {
                guard let url = try? content.fileURL() else { return }
                let barCount = Int(260 / Self.step)
                samples = (try? await AudioWaveformGenerator.generate(from: url, barCount: barCount)) ?? []
            }
        }

        private func waveCanvas(phase: Double) -> some View {
            Canvas { context, size in
                let barCount = Int(size.width / Self.step)
                guard barCount > 0 else { return }
                let color = content.primaryColor

                for i in 0..<barCount {
                    let base: CGFloat
                    if samples.isEmpty {
                        let s = Double(i)
                        base = CGFloat(0.2 + 0.7 * abs(sin(s * 0.7 + 0.5) * cos(s * 0.3 + 1.1)))
                    } else {
                        let mappedIndex = Int(Double(i) / Double(barCount) * Double(samples.count))
                        base = CGFloat(samples[min(mappedIndex, samples.count - 1)])
                    }

                    let amplitude: CGFloat
                    if isPlaying {
                        let wave = sin(Double(i) * 0.45 + phase * 5.0)
                        let boost = CGFloat(0.6 + 0.4 * (wave * 0.5 + 0.5))
                        amplitude = max(base * boost, 0.06)
                    } else {
                        amplitude = max(base, 0.06)
                    }

                    let barHeight = amplitude * size.height
                    let x = CGFloat(i) * Self.step
                    let y = (size.height - barHeight) / 2
                    let rect = CGRect(x: x, y: y, width: Self.barWidth, height: barHeight)
                    let path = Path(roundedRect: rect, cornerRadius: 1.5)

                    let opacity = isPlaying ? (0.55 + 0.45 * Double(amplitude / size.height)) : 0.75
                    context.fill(path, with: .color(color.opacity(opacity)))
                }
            }
        }
    }
}



// MARK: - Highlight Ring Effect

private struct HighlightRingEffect: View {

    let cornerRadius: CGFloat

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.yellow, lineWidth: 1.5)
            .scaleEffect(1 + phase * 0.12)
            .opacity(Double(1 - phase) * 0.85)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Previews

#Preview("Playing") {
    VStack(spacing: .spacing(.medium)) {
        ModernContent.Button(
            content: Sound(
                id: "ABC",
                title: "A gente vai cansando",
                authorName: "F",   // teal
                duration: 120
            ),
            favorites: Set<String>(),
            highlighted: Set<String>(),
            nowPlaying: Set<String>(["ABC"]),
            selectedItems: Set<String>(),
            currentContentListMode: .constant(.regular)
        )
        ModernContent.Button(
            content: Sound(
                id: "DEF",
                title: "Às vezes o ódio é a única emoção possível",
                authorName: "K",   // indigo
                duration: 45
            ),
            favorites: Set<String>(),
            highlighted: Set<String>(),
            nowPlaying: Set<String>(["DEF"]),
            selectedItems: Set<String>(),
            currentContentListMode: .constant(.regular)
        )
    }
    .padding()
    .frame(width: 220)
}

#Preview("All Colors") {
    // Each authorName is a single letter A–M, which hashes to a distinct
    // palette index (0–12), guaranteeing every color is represented.
    let sounds: [Sound] = [
        Sound(title: "Red",    authorName: "A", duration: 2),
        Sound(title: "Orange", authorName: "B", duration: 2),
        Sound(title: "Yellow", authorName: "C", duration: 2),
        Sound(title: "Green",  authorName: "D", duration: 2),
        Sound(title: "Teal",   authorName: "E", duration: 2),
        Sound(title: "Blue",   authorName: "F", duration: 2),
        Sound(title: "Purple", authorName: "G", duration: 2),
        Sound(title: "Brown",  authorName: "H", duration: 2),
        Sound(title: "Pink",   authorName: "I", duration: 2),
        Sound(title: "Cyan",   authorName: "J", duration: 2),
        Sound(title: "Indigo", authorName: "K", duration: 2),
        Sound(title: "Mint",   authorName: "L", duration: 2),
        Sound(title: "Gray",   authorName: "M", duration: 2),
    ]

    ScrollView {
        VStack(spacing: .spacing(.medium)) {
            ForEach(sounds) { sound in
                ModernContent.Button(
                    content: sound,
                    favorites: Set<String>(),
                    highlighted: Set<String>(),
                    nowPlaying: Set<String>(),
                    selectedItems: Set<String>(),
                    currentContentListMode: .constant(.regular)
                )
            }
        }
        .padding(.horizontal)
    }
    .frame(width: 220)
}

#Preview("Regular") {
    VStack(spacing: 15) {
        HStack(spacing: 15) {
            ModernContent.Button(
                content: Sound(
                    id: "ABC",
                    title: "A gente vai cansando",
                    authorName: "Filósofo da CEAGESP",
                    dateAdded: .now - 1_000_000, // 11.6 days
                    duration: 2
                ),
                favorites: Set<String>(),
                highlighted: Set<String>(),
                nowPlaying: Set<String>(),
                selectedItems: Set<String>(),
                currentContentListMode: .constant(.regular)
            )

            ModernContent.Button(
                content: Sound(
                    id: "DEF",
                    title: "Às vezes o ódio é a única emoção possível",
                    authorName: "Soraya Thronicke",
                    dateAdded: .now - 1_000_000, // 11.6 days
                    duration: 2
                ),
                favorites: Set<String>(),
                highlighted: Set<String>(),
                nowPlaying: Set<String>(),
                selectedItems: Set<String>(),
                currentContentListMode: .constant(.regular)
            )
        }

        ModernContent.Button(
            content: Sound(
                id: "DEF",
                title: "É simples assim, um manda e o outro obedece",
                authorName: "Soraya Thronicke",
                dateAdded: .now - 1_000_000, // 11.6 days
                duration: 2
            ),
            favorites: Set<String>(),
            highlighted: Set<String>(),
            nowPlaying: Set<String>(),
            selectedItems: Set<String>(),
            currentContentListMode: .constant(.regular)
        )
    }
    .padding()
}

#Preview("Favorite") {
    VStack(spacing: 15) {
        HStack(spacing: 15) {
            ModernContent.Button(
                content: Sound(
                    id: "ABC",
                    title: "A gente vai cansando",
                    authorName: "G",
                    duration: 2
                ),
                favorites: Set<String>(arrayLiteral: "ABC"),
                highlighted: Set<String>(),
                nowPlaying: Set<String>(),
                selectedItems: Set<String>(),
                currentContentListMode: .constant(.regular)
            )

            ModernContent.Button(
                content: Sound(
                    id: "DEF",
                    title: "A gente vai cansando",
                    authorName: "H",
                    duration: 2
                ),
                favorites: Set<String>(arrayLiteral: "DEF"),
                highlighted: Set<String>(),
                nowPlaying: Set<String>(),
                selectedItems: Set<String>(),
                currentContentListMode: .constant(.regular)
            )
        }
    }
    .padding()
}

#Preview("Playing") {
    VStack(spacing: 15) {
        HStack(spacing: 15) {
            ModernContent.Button(
                content: Sound(
                    id: "ABC",
                    title: "A gente vai cansando",
                    authorName: "Filósofo da CEAGESP",
                    duration: 2
                ),
                favorites: Set<String>(arrayLiteral: "ABC"),
                highlighted: Set<String>(),
                nowPlaying: Set<String>(arrayLiteral: "ABC"),
                selectedItems: Set<String>(),
                currentContentListMode: .constant(.regular)
            )

            ModernContent.Button(
                content: Sound(
                    id: "DEF",
                    title: "A gente vai cansando",
                    authorName: "Soraya Thronicke",
                    duration: 2
                ),
                favorites: Set<String>(),
                highlighted: Set<String>(),
                nowPlaying: Set<String>(arrayLiteral: "DEF"),
                selectedItems: Set<String>(),
                currentContentListMode: .constant(.regular)
            )
        }

        ModernContent.Button(
            content: Sound(
                id: "DEF",
                title: "A gente vai cansando",
                authorName: "Soraya Thronicke",
                duration: 2
            ),
            favorites: Set<String>(),
            highlighted: Set<String>(),
            nowPlaying: Set<String>(arrayLiteral: "DEF"),
            selectedItems: Set<String>(),
            currentContentListMode: .constant(.regular)
        )
    }
    .padding()
}

#Preview("New Tag") {
    ModernContent.Button(
        content: Sound(
            id: "ABC",
            title: "A decisão não cabe a gente, cabe ao TSE",
            authorName: "Paulo Sérgio Nogueira",
            duration: 2
        ),
        favorites: Set<String>(),
        highlighted: Set<String>(),
        nowPlaying: Set<String>(),
        selectedItems: Set<String>(),
        currentContentListMode: .constant(.regular)
    )
    .padding()
}

#Preview("Highlighted") {
    ModernContent.Button(
        content: Sound(
            id: "JKL",
            title: "Bom dia",
            authorName: "Hamilton Mourão",
            duration: 2
        ),
        favorites: Set<String>(),
        highlighted: Set<String>(arrayLiteral: "JKL"),
        nowPlaying: Set<String>(),
        selectedItems: Set<String>(),
        currentContentListMode: .constant(.regular)
    )
    .padding()
}
