//
//  StoriesView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 20/10/24.
//

import SwiftUI

/// The year-end Retrospectiva: full-screen pages that move on by themselves, like stories.
/// Tap the edges to go back and forth, hold to pause, swipe down to close.
struct StoriesView: View {

    var onShareAnalytics: ((String) -> Void)?

    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ViewModel

    init(year: Int = 2026, onShareAnalytics: ((String) -> Void)? = nil) {
        self.onShareAnalytics = onShareAnalytics
        _viewModel = StateObject(wrappedValue: ViewModel(year: year))
    }

    @State private var currentStoryIndex: Int = 0
    @State private var progress: CGFloat = 0.0
    @State private var timerActive: Bool = false
    @State private var isMuted: Bool = false
    @State private var isLongPressing: Bool = false

    private let progressUpdateInterval: TimeInterval = 0.05
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    /// Whether we're on the final story (share page) - timer should not auto-advance
    private var isOnFinalStory: Bool {
        currentStoryIndex == viewModel.stories.count - 1
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                Color.black.ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            } else if !viewModel.stories.isEmpty {
                currentStory.backgroundColor.view()
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.35), value: currentStoryIndex)

                VStack(spacing: 0) {
                    StoryProgressIndicator(
                        numberOfStories: viewModel.stories.count,
                        currentStoryIndex: currentStoryIndex,
                        currentProgress: progress,
                        tint: chromeColor
                    )
                    .zIndex(100)

                    ZStack {
                        storyContentView(for: currentStoryIndex)
                    }
                    .id(currentStoryIndex)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Tap zones for navigation (edge strips only)
                .overlay {
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: 60)
                            .onTapGesture {
                                goToPreviousStory()
                            }

                        Spacer()

                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: 60)
                            .onTapGesture {
                                goToNextStory()
                            }
                    }
                }

                // Close button (after tap zones so it's on top)
                .overlay(alignment: .topTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(chromeColor)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Fechar")
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }

                // Mute button (bottom left) - only on audio stories
                .overlay(alignment: .bottomLeading) {
                    if currentPage?.topSoundIndex != nil {
                        Button {
                            isMuted.toggle()
                            if isMuted {
                                AudioPlayer.shared?.cancel()
                            }
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(isMuted ? "Ligar o som" : "Desligar o som")
                        .padding(.leading, 16)
                        .padding(.bottom, 40)
                    }
                }

                // Long press to pause - using DragGesture for continuous press detection
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isLongPressing {
                                isLongPressing = true
                            }
                        }
                        .onEnded { _ in
                            isLongPressing = false
                        }
                )
            }
        }
        .statusBar(hidden: true)
        .task {
            await viewModel.loadData()
            startTimer()
        }
        .onDisappear {
            stopTimer()
            AudioPlayer.shared?.cancel()
        }
        .onReceive(timer) { _ in
            guard timerActive && !isLongPressing else { return }

            // Don't auto-advance on the final story (share page)
            if isOnFinalStory {
                progress = min(progress + CGFloat(progressUpdateInterval / currentStory.duration), 1.0)
                return
            }

            let increment = CGFloat(progressUpdateInterval / currentStory.duration)
            progress += increment

            if progress >= 1.0 {
                goToNextStory()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Dismiss if swiped down significantly
                    if value.translation.height > 100 {
                        dismiss()
                    }
                }
        )
    }

    // MARK: - Computed Properties

    private var currentStory: Story {
        guard currentStoryIndex < viewModel.stories.count else {
            return viewModel.stories.last ?? Story(id: "default")
        }
        return viewModel.stories[currentStoryIndex]
    }

    private var currentPage: StoryPage? {
        StoryPage(rawValue: currentStory.id)
    }

    /// Progress bars and the close button, dark on the light pages.
    private var chromeColor: Color {
        currentPage?.isLight == true ? RetroPalette.deepRed : .white
    }

    // MARK: - Story Content Views

    @ViewBuilder
    private func storyContentView(for index: Int) -> some View {
        if index < viewModel.stories.count, let page = StoryPage(rawValue: viewModel.stories[index].id) {
            switch page {
            case .intro:
                IntroStory(year: viewModel.yearNumber)

            case .shares:
                SharesStory(
                    year: viewModel.yearNumber,
                    total: viewModel.totalShareCount,
                    unique: viewModel.totalUniqueSoundsShared,
                    perWeek: viewModel.sharesPerWeek
                )

            case .topAuthor:
                if let author = viewModel.topAuthor {
                    TopAuthorStory(author: author)
                }

            case .topSound1, .topSound2, .topSound3:
                if let index = page.topSoundIndex, let sound = viewModel.topSound(at: index) {
                    TopSoundStory(
                        rank: index + 1,
                        item: sound,
                        authorPhoto: viewModel.authorPhotos[sound.contentAuthorId],
                        isMuted: $isMuted
                    )
                }

            case .listening:
                ListeningStory(
                    year: viewModel.yearNumber,
                    secondsListened: viewModel.secondsListened,
                    days: viewModel.listeningDays,
                    finished: viewModel.episodesFinished
                )

            case .topEpisode:
                if let episode = viewModel.topEpisode {
                    TopEpisodeStory(episode: episode)
                }

            case .habits:
                HabitsStory(
                    favoriteDay: viewModel.mostCommonShareDay == "-" ? nil : viewModel.mostCommonShareDay,
                    longestStreak: viewModel.longestListeningStreak
                )

            case .share:
                ShareStory(
                    year: viewModel.yearNumber,
                    topAuthor: viewModel.topAuthor,
                    topSounds: viewModel.topSounds,
                    totalShares: viewModel.totalShareCount,
                    favoriteDay: viewModel.mostCommonShareDay,
                    secondsListened: viewModel.hasEpisodes ? viewModel.secondsListened : 0,
                    topEpisodeTitle: viewModel.hasEpisodes ? viewModel.topEpisode?.title : nil,
                    onShareTapped: {
                        onShareAnalytics?(viewModel.analyticsString())
                    }
                )
            }
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        progress = 0.0
        timerActive = true
    }

    private func stopTimer() {
        timerActive = false
    }

    // MARK: - Navigation

    private func goToNextStory() {
        // Stop any currently playing audio before changing stories
        AudioPlayer.shared?.cancel()

        if currentStoryIndex < viewModel.stories.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStoryIndex += 1
            }
            progress = 0.0
        } else {
            // Reached the end
            stopTimer()
            dismiss()
        }
    }

    private func goToPreviousStory() {
        // Stop any currently playing audio before changing stories
        AudioPlayer.shared?.cancel()

        if currentStoryIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStoryIndex -= 1
            }
            progress = 0.0
        }
    }
}

// MARK: - Preview

#Preview {
    StoriesView()
}
