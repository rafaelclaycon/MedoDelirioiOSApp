//
//  RetroStoryPages.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/10/26.
//

import SwiftUI
import Kingfisher

// MARK: - Building Blocks

/// Slides a block up into place, one after the other on each page. Fades only with
/// Reduce Motion.
private struct StoryEntrance: ViewModifier {

    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown || reduceMotion ? 0 : 28)
            .scaleEffect(isShown || reduceMotion ? 1 : 0.96, anchor: .bottomLeading)
            .onAppear {
                withAnimation(.spring(duration: 0.7, bounce: 0.25).delay(delay)) {
                    isShown = true
                }
            }
    }
}

private extension View {

    func storyEntrance(_ delay: Double = 0) -> some View {
        modifier(StoryEntrance(delay: delay))
    }
}

/// The small line over a page's big statement.
private struct StoryKicker: View {

    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 15, weight: .heavy))
            .tracking(1.8)
            .opacity(0.75)
    }
}

/// A big number that rolls up from zero when the page opens.
private struct RollingNumber: View {

    let value: Int
    let size: CGFloat

    @State private var shown = 0

    var body: some View {
        Text(MonthlyStats.formattedNumber(shown))
            .font(.system(size: size, weight: .black, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .contentTransition(.numericText(value: Double(shown)))
            .onAppear {
                withAnimation(.smooth(duration: 1.3).delay(0.35)) {
                    shown = value
                }
            }
    }
}

/// A flat disc half off the page, the one shape behind the type.
private struct StoryOrb: View {

    let color: Color
    var size: CGFloat = 460
    var alignment: Alignment = .bottomTrailing
    var offset = CGSize(width: 160, height: 140)

    @State private var isShown = false

    /// An overlay on a clear page, so a disc bigger than the screen can't stretch the
    /// page with it.
    var body: some View {
        Color.clear
            .overlay(alignment: alignment) {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(isShown ? 1 : 0.6)
                    .offset(offset)
            }
            .clipped()
            .onAppear {
                withAnimation(.spring(duration: 1.1, bounce: 0.2)) {
                    isShown = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// A fact under the headline: a rule, then the line.
private struct StoryFact: View {

    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .frame(width: 36, height: 3)
                .opacity(0.5)
            Text(text)
                .font(.system(size: 22, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Every page: left-aligned, centered in the height, clear of the progress bars and the
/// mute button.
private struct StoryPageLayout<Content: View>: View {

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 60)
            content
            Spacer(minLength: 100)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }
}

// MARK: - Intro

struct IntroStory: View {

    let year: Int

    var body: some View {
        ZStack {
            StoryOrb(color: RetroPalette.deepRed)

            StoryPageLayout {
                StoryKicker(text: "Medo e Delírio em Brasília")
                    .storyEntrance(0.1)

                Text("Sua\nRetrospectiva")
                    .font(.system(size: 48, weight: .heavy))
                    .padding(.top, 10)
                    .storyEntrance(0.25)

                HStack(spacing: 0) {
                    ForEach(Array(String(year).enumerated()), id: \.offset) { index, digit in
                        Text(String(digit))
                            .storyEntrance(0.5 + Double(index) * 0.12)
                    }
                }
                .font(.system(size: 124, weight: .black, design: .rounded))
                .foregroundStyle(RetroPalette.red)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Shares

struct SharesStory: View {

    let year: Int
    let total: Int
    let unique: Int
    let perWeek: Int

    var body: some View {
        ZStack {
            StoryOrb(color: .white.opacity(0.12), alignment: .topTrailing, offset: CGSize(width: 180, height: -120))

            StoryPageLayout {
                StoryKicker(text: "Em \(year) você compartilhou")
                    .storyEntrance(0.1)

                RollingNumber(value: total, size: 128)
                    .storyEntrance(0.2)

                Text(total == 1 ? "Vírgula" : "Vírgulas")
                    .font(.system(size: 44, weight: .heavy))
                    .storyEntrance(0.35)

                VStack(alignment: .leading, spacing: 22) {
                    if unique > 1 {
                        StoryFact(text: "\(MonthlyStats.formattedNumber(unique)) diferentes")
                    }
                    if perWeek >= 1 {
                        StoryFact(text: "\(MonthlyStats.formattedNumber(perWeek)) por semana, em média")
                    }
                }
                .padding(.top, 36)
                .storyEntrance(0.9)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Top Author

struct TopAuthorStory: View {

    let author: TopAuthorItem

    var body: some View {
        ZStack {
            StoryOrb(color: RetroPalette.red.opacity(0.5), alignment: .topLeading, offset: CGSize(width: -180, height: -100))

            StoryPageLayout {
                StoryKicker(text: "Seu autor do ano")
                    .storyEntrance(0.1)

                KFImage(URL(string: author.authorPhoto ?? ""))
                    .placeholder {
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.1))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 230, height: 230)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(RetroPalette.cream, lineWidth: 6))
                    .padding(.vertical, 28)
                    .storyEntrance(0.25)

                Text(author.authorName)
                    .font(.system(size: 42, weight: .heavy))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .storyEntrance(0.45)

                Text(MonthlyStats.counted(author.shareCount, "compartilhamento", "compartilhamentos"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RetroPalette.cream)
                    .padding(.top, 8)
                    .storyEntrance(0.6)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Top Sounds

/// One step of the countdown, playing the Vírgula. The number one gets the cream page.
struct TopSoundStory: View {

    let rank: Int
    let item: TopChartItem
    let authorPhoto: String?
    @Binding var isMuted: Bool

    @State private var soundLoadFailed = false

    private var ink: Color { rank == 1 ? RetroPalette.red : .white }

    var body: some View {
        ZStack {
            Color.clear
                .overlay(alignment: .bottomTrailing) {
                    Text("\(rank)")
                        .font(.system(size: 460, weight: .black, design: .rounded))
                        .foregroundStyle(ink.opacity(0.1))
                        .fixedSize()
                        .offset(x: 120, y: 120)
                }
                .clipped()
                .storyEntrance(0)
                .accessibilityHidden(true)

            StoryPageLayout {
                StoryKicker(text: rank == 1 ? "Sua Vírgula do ano" : "Sua Vírgula nº \(rank)")
                    .storyEntrance(0.1)

                Text(item.contentName)
                    .font(.system(size: 44, weight: .heavy))
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 12)
                    .storyEntrance(0.25)

                HStack(spacing: 10) {
                    KFImage(URL(string: authorPhoto ?? ""))
                        .placeholder { Circle().fill(ink.opacity(0.2)) }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    Text(item.contentAuthorName)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                }
                .padding(.top, 18)
                .storyEntrance(0.45)

                Text(MonthlyStats.counted(item.shareCount, "compartilhamento", "compartilhamentos"))
                    .font(.system(size: 17, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(ink.opacity(0.14)))
                    .padding(.top, 22)
                    .storyEntrance(0.6)

                if soundLoadFailed {
                    Label("Som indisponível", systemImage: "speaker.slash")
                        .font(.caption)
                        .opacity(0.6)
                        .padding(.top, 10)
                }
            }
        }
        .foregroundStyle(ink)
        .onAppear {
            playSound()
        }
        .onChange(of: isMuted) { _, isMuted in
            if isMuted {
                AudioPlayer.shared?.cancel()
            } else {
                playSound()
            }
        }
    }

    private func playSound() {
        guard !isMuted else { return }
        do {
            guard let sound = try LocalDatabase.shared.sound(withId: item.contentId) else {
                soundLoadFailed = true
                return
            }
            AudioPlayer.shared = AudioPlayer(url: try sound.fileURL(), update: { _ in })
            AudioPlayer.shared?.togglePlay()
        } catch {
            soundLoadFailed = true
        }
    }
}

// MARK: - Listening

struct ListeningStory: View {

    let year: Int
    let secondsListened: Double
    let days: Int
    let finished: Int

    private var hours: Int { Int(secondsListened / 3600) }

    var body: some View {
        ZStack {
            StoryOrb(color: .white.opacity(0.08), size: 520)

            StoryPageLayout {
                StoryKicker(text: "Em \(year) você ouviu")
                    .storyEntrance(0.1)

                Group {
                    if hours >= 10 {
                        RollingNumber(value: hours, size: 128)
                    } else {
                        Text(MonthlyStats.formattedDuration(secondsListened))
                            .font(.system(size: 88, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .foregroundStyle(RetroPalette.coral)
                .storyEntrance(0.2)

                Text(hours >= 10 ? "horas de episódios" : "de episódios")
                    .font(.system(size: 40, weight: .heavy))
                    .storyEntrance(0.35)

                VStack(alignment: .leading, spacing: 22) {
                    StoryFact(text: "em \(MonthlyStats.counted(days, "dia", "dias diferentes"))")
                    if finished > 0 {
                        StoryFact(text: "\(MonthlyStats.counted(finished, "episódio ouvido", "episódios ouvidos")) até o fim")
                    }
                }
                .padding(.top, 36)
                .storyEntrance(0.9)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Top Episode

/// The artwork carries this one: big, and blurred behind everything.
struct TopEpisodeStory: View {

    let episode: MonthlyStats.RankedEpisode

    var body: some View {
        ZStack {
            // An overlay, so filling the screen can't make the page wider than it.
            Color.clear
                .overlay {
                    KFImage(episode.imageURL)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 60)
                        .opacity(0.55)
                }
                .clipped()
                .accessibilityHidden(true)

            StoryPageLayout {
                StoryKicker(text: "Seu episódio do ano")
                    .storyEntrance(0.1)

                KFImage(episode.imageURL)
                    .placeholder {
                        Image(systemName: "headphones")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.1))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 250, height: 250)
                    .clipShape(.rect(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                    .padding(.vertical, 28)
                    .storyEntrance(0.25)

                Text(episode.title)
                    .font(.system(size: 32, weight: .heavy))
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .storyEntrance(0.45)

                Text("\(MonthlyStats.formattedDuration(episode.secondsListened)) com ele")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RetroPalette.coral)
                    .padding(.top, 10)
                    .storyEntrance(0.6)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Habits

struct HabitsStory: View {

    let favoriteDay: String?
    let longestStreak: Int

    var body: some View {
        ZStack {
            StoryOrb(color: .white.opacity(0.12), alignment: .bottomLeading, offset: CGSize(width: -200, height: 160))

            StoryPageLayout {
                StoryKicker(text: "Seus hábitos")
                    .storyEntrance(0.1)

                VStack(alignment: .leading, spacing: 40) {
                    if let favoriteDay {
                        block(label: "Seu dia de compartilhar", value: favoriteDay)
                            .storyEntrance(0.25)
                    }
                    if longestStreak >= 2 {
                        block(label: "Sua maior sequência ouvindo", value: "\(longestStreak) dias seguidos")
                            .storyEntrance(0.5)
                    }
                }
                .padding(.top, 24)
            }
        }
        .foregroundStyle(.white)
    }

    private func block(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 20, weight: .semibold))
                .opacity(0.8)
            Text(value)
                .font(.system(size: 52, weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Previews

#Preview("Intro") {
    IntroStory(year: 2026).background(.black)
}

#Preview("Shares") {
    SharesStory(year: 2026, total: 1247, unique: 312, perWeek: 29).background(RetroPalette.red)
}

#Preview("Number One") {
    TopSoundStory(
        rank: 1,
        item: TopChartItem(id: "1", rankNumber: "1", contentId: "x", contentName: "Uma Vírgula de exemplo", contentAuthorId: "a", contentAuthorName: "Autor de Exemplo", shareCount: 42),
        authorPhoto: nil,
        isMuted: .constant(true)
    )
    .background(RetroPalette.cream)
}

#Preview("Listening") {
    ListeningStory(year: 2026, secondsListened: 150_000, days: 87, finished: 23).background(RetroPalette.wine)
}

#Preview("Habits") {
    HabitsStory(favoriteDay: "Terça-feira", longestStreak: 12).background(RetroPalette.red)
}
