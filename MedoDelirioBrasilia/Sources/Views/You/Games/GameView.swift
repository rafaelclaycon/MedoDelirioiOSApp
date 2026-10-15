//
//  GameView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import SwiftUI
import Kingfisher
import os

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "GameView")

/// A game, full screen: ten rounds of picking whose face or voice it is, then the
/// result.
struct GameView: View {

    let kind: GameKind
    let scoreStore: GameScoreStore

    @Environment(\.dismiss) private var dismiss
    @Environment(EpisodePlayer.self) private var episodePlayer

    @State private var session: GameSession?
    @State private var soundPlayer = GameSoundPlayer()
    @State private var musicPlayer = GameMusicPlayer()
    @State private var isNewRecord = false

    var body: some View {
        NavigationStack {
            Group {
                if let session, !session.rounds.isEmpty {
                    if session.isFinished {
                        ResultView(
                            kind: kind,
                            hits: session.hits,
                            points: session.points,
                            total: session.rounds.count,
                            isNewRecord: isNewRecord,
                            playAgain: { start() },
                            close: { dismiss() }
                        )
                    } else if let round = session.current {
                        RoundView(
                            session: session,
                            round: round,
                            soundPlayer: soundPlayer,
                            pick: { pick($0, in: session) },
                            next: { next(in: session) },
                            photoFailed: { id, photo in photoFailed(roundID: id, photo: photo, in: session) }
                        )
                        .task(id: round.id) {
                            await checkUpcomingPhoto(in: session)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Ainda não dá pra jogar",
                        systemImage: kind.systemImage,
                        description: Text("Faltam vírgulas com autor neste aparelho. Tente de novo depois da próxima atualização de conteúdo.")
                    )
                }
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                LinearGradient(
                    colors: [kind.accentColor.opacity(0.25), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
            .navigationTitle(kind.title)
            // The background song, under the title: out of the game's way, but there
            // for anyone wondering what's playing.
            .navigationSubtitle(musicPlayer.songTitle.map { "♪ \($0)" } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Fechar")
                }

                if kind == .whoseFace {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            musicPlayer.toggleMute()
                            let action = musicPlayer.isMuted ? "game_music_muted" : "game_music_unmuted"
                            Task {
                                await AnalyticsService().send(originatingScreen: "GameView", action: action)
                            }
                        } label: {
                            Image(systemName: musicPlayer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityLabel(musicPlayer.isMuted ? "Ligar a música" : "Silenciar a música")
                    }
                }
            }
        }
        .onAppear {
            // Both games play audio (sounds or music), which shouldn't fight an episode.
            if episodePlayer.isPlaying {
                episodePlayer.togglePlayPause()
            }
            start()
        }
        .onDisappear {
            soundPlayer.stop()
            musicPlayer.stop()
            reportAbandonmentIfNeeded()
        }
        // Also reached by dropping a last round whose photo failed, not only by "Ver
        // resultado".
        .onChange(of: session?.isFinished ?? false) { _, isFinished in
            if isFinished, let session {
                finish(session)
            }
        }
    }

    // MARK: - Flow

    private func start() {
        soundPlayer.stop()
        isNewRecord = false
        let rounds = makeRounds()
        guard !rounds.isEmpty else {
            session = nil
            return
        }
        if let session {
            session.restart(with: rounds)
        } else {
            session = GameSession(kind: kind, rounds: rounds)
        }
        // A different song every game. The voice game needs silence to be heard.
        if kind == .whoseFace {
            AudioPlayer.shared?.stop()
            musicPlayer.playRandomSong()
        }
        Task {
            await AnalyticsService().send(originatingScreen: "GameView", action: "didStartGame(\(kind.rawValue))")
        }
    }

    private func pick(_ author: Author, in session: GameSession) {
        withAnimation(.snappy) {
            if session.pick(author) {
                HapticFeedback.success()
            } else {
                HapticFeedback.error()
            }
        }
    }

    private func next(in session: GameSession) {
        soundPlayer.stop()
        withAnimation(.spring(duration: 0.55, bounce: 0.15)) {
            session.advance()
        }
    }

    private func finish(_ session: GameSession) {
        isNewRecord = scoreStore.record(session.score, for: kind)
        do {
            try LocalDatabase.shared.insert(gameResult: GameResult(session: session))
        } catch {
            logger.error("Couldn't save the game result: \(error.localizedDescription, privacy: .public)")
        }
        if isNewRecord {
            HapticFeedback.success()
        }
        // Enough to tell whether a game is too hard or too easy, not just how it ended.
        let averageSeconds = session.averageAnswerSeconds.map { String(format: "%.1f", $0) } ?? "nil"
        let action = "didFinishGame(\(kind.rawValue), score: \(session.score), hits: \(session.hits), "
            + "rounds: \(session.rounds.count), avgSeconds: \(averageSeconds), newRecord: \(isNewRecord))"
        Task {
            await AnalyticsService().send(originatingScreen: "GameView", action: action)
        }
    }

    /// Leaving before the result, so it shows where people give up. A finished game,
    /// or one that never had rounds, isn't one.
    private func reportAbandonmentIfNeeded() {
        guard let session, !session.rounds.isEmpty, !session.isFinished else { return }
        let action = "didAbandonGame(\(kind.rawValue), round: \(session.index + 1), of: \(session.rounds.count), "
            + "answered: \(session.isRevealed))"
        Task {
            await AnalyticsService().send(originatingScreen: "GameView", action: action)
        }
    }

    /// Voice rounds only use sounds whose file is on this device, and respect the
    /// explicit content setting.
    private func makeRounds() -> [GameRound] {
        var generator = SystemRandomNumberGenerator()
        let authors = (try? LocalDatabase.shared.allAuthors()) ?? []
        let count = GameRoundFactory.roundCount + GameRoundFactory.spareCount
        switch kind {
        case .whoseFace:
            let showable = authors.filter { !Self.brokenPhotos.contains($0.photo ?? "") }
            return GameRoundFactory.faceRounds(authors: showable, count: count, using: &generator)
        case .whoseVoice:
            let allowSensitive = UserSettings().getShowExplicitContent()
            let sounds = ((try? LocalDatabase.shared.sounds(allowSensitive: allowSensitive)) ?? [])
                .filter { (try? $0.fileURL()) != nil }
            return GameRoundFactory.voiceRounds(sounds: sounds, authors: authors, count: count, using: &generator)
        }
    }

    // MARK: - Broken Photos

    /// Photos that failed to load since launch, left out of later games. They're
    /// hosted elsewhere and do go offline now and then.
    @MainActor private static var brokenPhotos = Set<String>()

    /// Long enough for a slow connection, short enough not to leave someone staring at
    /// a spinner mid-game.
    static let photoTimeout: TimeInterval = 8

    /// Swaps the round for a spare, and reports the photo so it can be fixed.
    private func photoFailed(roundID: GameRound.ID, photo: String, in session: GameSession) {
        guard let authorID = session.rounds.first(where: { $0.id == roundID })?.answer.id else { return }
        Self.brokenPhotos.insert(photo)
        logger.warning("Author photo didn't load, swapping the round: \(authorID, privacy: .public) \(photo, privacy: .public)")
        Task {
            await AnalyticsService().send(originatingScreen: "GameView", action: "didFindBrokenAuthorPhoto(\(authorID))")
        }
        withAnimation(.smooth) {
            _ = session.replaceRound(id: roundID)
        }
    }

    /// Loads the next round's photo while this one is up, so a broken one is swapped
    /// before anyone sees it, and a good one shows up instantly. Keeps going until the
    /// next round's photo loads or there's nothing left to swap in.
    private func checkUpcomingPhoto(in session: GameSession) async {
        while !Task.isCancelled {
            let next = session.index + 1
            guard session.rounds.indices.contains(next),
                  case .photo(let photo) = session.rounds[next].prompt,
                  let url = URL(string: photo)
            else { return }
            let roundID = session.rounds[next].id

            do {
                _ = try await KingfisherManager.shared.retrieveImage(
                    with: url,
                    options: [.requestModifier(AnyModifier { request in
                        var request = request
                        request.timeoutInterval = Self.photoTimeout
                        return request
                    })]
                )
                return
            } catch {
                guard !Task.isCancelled else { return }
                photoFailed(roundID: roundID, photo: photo, in: session)
            }
        }
    }
}

// MARK: - Round

extension GameView {

    struct RoundView: View {

        let session: GameSession
        let round: GameRound
        let soundPlayer: GameSoundPlayer
        let pick: (Author) -> Void
        let next: () -> Void
        let photoFailed: (GameRound.ID, String) -> Void

        var body: some View {
            VStack(spacing: .spacing(.medium)) {
                header

                Spacer(minLength: 0)

                prompt

                Text(session.kind.question)
                    .font(.system(.title2, design: .rounded))
                    .bold()

                if session.kind.scoring == .points {
                    PointsChip(session: session)
                }

                Spacer(minLength: 0)

                VStack(spacing: .spacing(.small)) {
                    ForEach(round.options) { author in
                        OptionButton(
                            name: author.name,
                            state: state(of: author),
                            action: { pick(author) }
                        )
                        .disabled(session.isRevealed)
                    }
                }

                footer
            }
            .padding()
        }

        private var header: some View {
            VStack(spacing: .spacing(.xSmall)) {
                HStack {
                    Text("Pergunta \(session.index + 1) de \(session.rounds.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())

                    Spacer()

                    Label(scoreText, systemImage: "star.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(session.kind.accentColor)
                        .contentTransition(.numericText())
                        .accessibilityLabel(scoreAccessibilityLabel)
                }

                ProgressView(
                    value: Double(session.index + (session.isRevealed ? 1 : 0)),
                    total: Double(session.rounds.count)
                )
                .tint(session.kind.accentColor)
            }
        }

        private var scoreText: String {
            switch session.kind.scoring {
            case .hits: "\(session.hits)"
            case .points: GameScoring.formattedPoints(session.points)
            }
        }

        private var scoreAccessibilityLabel: String {
            switch session.kind.scoring {
            case .hits: "\(session.hits) acertos"
            case .points: GameScoring.formattedPoints(session.points)
            }
        }

        @ViewBuilder
        private var prompt: some View {
            switch round.prompt {
            case .photo:
                // One deck across rounds, not one per round, so the cards can move up
                // and flip as the game goes.
                CardDeckView(
                    session: session,
                    photoFailed: photoFailed,
                    photoLoaded: { id in
                        // A late load for a round already gone shouldn't start the next.
                        if id == session.current?.id {
                            session.startClock()
                        }
                    }
                )

            case .sound(let sound):
                VStack(spacing: .spacing(.small)) {
                    Button {
                        soundPlayer.play(sound)
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 64, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: soundPlayer.isPlaying)
                            .frame(width: 160, height: 160)
                            .background {
                                MeshGradient(
                                    width: 3,
                                    height: 3,
                                    points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.5, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                                    colors: session.kind.meshColors
                                )
                            }
                            .clipShape(Circle())
                            .shadow(color: session.kind.accentColor.opacity(0.4), radius: 16, y: 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ouvir de novo")

                    // Both lines always laid out in one fixed-height slot, one of them
                    // hidden, so revealing the title doesn't push anything around.
                    ZStack {
                        Text("Toque para ouvir de novo")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .opacity(session.isRevealed ? 0 : 1)

                        Text("“\(sound.title)”")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .opacity(session.isRevealed ? 1 : 0)
                            .accessibilityHidden(!session.isRevealed)
                    }
                    .frame(height: Self.soundCaptionHeight)
                }
                .id(round.id)
                .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                .task(id: round.id) {
                    soundPlayer.play(sound)
                    // Answer times count from the sound, like the face game's from
                    // the photo.
                    session.startClock()
                }
            }
        }

        /// Always laid out, so revealing the answer doesn't push the options around.
        /// Two lines of headline, the most the sound's title takes.
        private static let soundCaptionHeight: CGFloat = 48

        /// Empty unless the round is answered: the footer fades out as the next round
        /// comes in, and a text worked out from the current round would show the next
        /// answer on its way out.
        private var verdict: String {
            guard session.isRevealed else { return " " }
            return session.pickedCorrectly ? "Acertou!" : "Era \(round.answer.name)."
        }

        private var footer: some View {
            VStack(spacing: .spacing(.small)) {
                // The face game says it on the card.
                if session.kind == .whoseVoice {
                    Text(verdict)
                        .font(.headline)
                        .foregroundStyle(session.pickedCorrectly ? .green : .red)
                        // One line, so a long name can't make the footer taller.
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Button {
                    next()
                } label: {
                    Text(session.isLastRound ? "Ver resultado" : "Próxima")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(session.kind.accentColor)
                .controlSize(.large)
            }
            .opacity(session.isRevealed ? 1 : 0)
            .allowsHitTesting(session.isRevealed)
            .accessibilityHidden(!session.isRevealed)
        }

        private func state(of author: Author) -> OptionButton.State {
            guard session.isRevealed else { return .idle }
            if author.id == round.answer.id { return .right }
            if author.id == session.pickedID { return .wrong }
            return .dimmed
        }
    }
}

// MARK: - Points Chip

extension GameView {

    /// What answering now is worth, ticking down while the photo sharpens; once
    /// answered, what the round earned.
    struct PointsChip: View {

        let session: GameSession

        var body: some View {
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                let content = content(at: context.date)
                Label(content.text, systemImage: content.symbol)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(content.color)
                    .contentTransition(.numericText(countsDown: true))
                    .padding(.horizontal, .spacing(.small))
                    .padding(.vertical, .spacing(.xxSmall))
                    .background(Capsule().fill(content.color.opacity(0.15)))
                    .animation(.snappy, value: content.text)
            }
        }

        private func content(at date: Date) -> (text: String, symbol: String, color: Color) {
            if let earned = session.roundPoints {
                return earned > 0
                    ? ("+\(GameScoring.formattedPoints(earned))", "checkmark", .green)
                    : ("Nenhum ponto", "xmark", .red)
            }
            let elapsed = session.roundStartedAt.map { date.timeIntervalSince($0) } ?? 0
            let worth = GameScoring.points(afterElapsed: elapsed)
            return ("Vale \(GameScoring.formattedPoints(worth))", "timer", session.kind.accentColor)
        }
    }
}

// MARK: - Option

extension GameView {

    struct OptionButton: View {

        enum State {
            case idle, right, wrong, dimmed
        }

        let name: String
        let state: State
        let action: () -> Void

        private var fill: Color {
            switch state {
            case .idle, .dimmed: Color(.secondarySystemGroupedBackground)
            case .right: .green
            case .wrong: .red
            }
        }

        private var symbol: String? {
            switch state {
            case .right: "checkmark.circle.fill"
            case .wrong: "xmark.circle.fill"
            case .idle, .dimmed: nil
            }
        }

        var body: some View {
            Button(action: action) {
                HStack {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.leading)

                    Spacer()

                    if let symbol {
                        Image(systemName: symbol)
                            .font(.title3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .foregroundStyle(state == .right || state == .wrong ? .white : .primary)
                .padding(.horizontal, .spacing(.medium))
                .frame(minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(fill)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                )
                .opacity(state == .dimmed ? 0.5 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityValue(state == .right ? "Resposta certa" : state == .wrong ? "Errado" : "")
        }
    }
}

// MARK: - Result

extension GameView {

    struct ResultView: View {

        let kind: GameKind
        let hits: Int
        let points: Int
        /// Usually ten; fewer if rounds had to be dropped.
        let total: Int
        let isNewRecord: Bool
        let playAgain: () -> Void
        let close: () -> Void

        /// By right answers, whatever the game scores by: points also reward speed,
        /// but "Gabaritou" is about knowing everyone.
        private var message: String {
            switch hits {
            case total: "Gabaritou! Você é da casa."
            case 7...: "Mandou muito bem!"
            case 4...6: "Nada mal. Dá pra melhorar."
            default: "Hora de maratonar uns episódios."
            }
        }

        var body: some View {
            VStack(spacing: .spacing(.large)) {
                Spacer()

                if hits == total {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(kind.accentColor)
                } else {
                    GameSymbol(kind: kind, size: 56, style: kind.accentColor)
                }

                VStack(spacing: .spacing(.xSmall)) {
                    switch kind.scoring {
                    case .hits:
                        Text("\(hits) de \(total)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    case .points:
                        Text(GameScoring.formattedPoints(points))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("\(hits) de \(total) acertos")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Text(message)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                }

                if isNewRecord {
                    Label("Novo recorde!", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacing(.medium))
                        .padding(.vertical, .spacing(.xSmall))
                        .background(Capsule().fill(kind.accentColor))
                }

                Spacer()

                VStack(spacing: .spacing(.small)) {
                    Button(action: playAgain) {
                        Text("Jogar de novo")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(kind.accentColor)

                    Button(action: close) {
                        Text("Fechar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                .controlSize(.large)
            }
            .padding()
        }
    }
}

// MARK: - Sound

/// Plays a round's sound. Its own player rather than `AudioPlayer.shared`, so it
/// doesn't take over the content grid's playing state; game plays aren't logged either,
/// so they stay out of Tendências.
@Observable
@MainActor
final class GameSoundPlayer {

    private(set) var isPlaying = false
    @ObservationIgnored private var player: AudioPlayer?

    func play(_ sound: Sound) {
        stop()
        // Anything playing from the content grid stops for the game.
        AudioPlayer.shared?.stop()
        guard let url = try? sound.fileURL() else { return }
        player = AudioPlayer(url: url) { [weak self] state in
            MainActor.assumeIsolated {
                self?.isPlaying = state?.activity == .playing
            }
        }
        player?.togglePlay()
        isPlaying = player != nil
    }

    func stop() {
        player?.cancel()
        player = nil
        isPlaying = false
    }
}

#Preview {
    GameView(kind: .whoseFace, scoreStore: GameScoreStore())
        .environment(EpisodePlayer())
}
