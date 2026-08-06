//
//  EpisodePlayer.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import AVFoundation
import Foundation
import MediaPlayer
import Network

/// Manages podcast episode download and playback.
///
/// Downloads episodes to local storage before playing them back using `AVAudioPlayer`.
/// Tracks download progress and playback state as observable properties so SwiftUI views
/// can reactively update.
///
/// Designed to be created once in `MainView` and shared via `.environment()`.
@Observable
final class EpisodePlayer {

    // MARK: - Observable State

    var currentEpisode: PodcastEpisode?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackSpeed: Float = {
        let stored = UserDefaults.standard.float(forKey: "episodePlaybackSpeed")
        return stored > 0 ? stored : 1.0
    }()

    static let availableSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    /// Download progress per episode ID (0.0 to 1.0). Empty when no downloads are active.
    var downloadProgress: [String: Double] = [:]

    /// The episode ID currently going through pre-download checks (cellular, HEAD request).
    /// Drives an indeterminate spinner on the play button for immediate tap feedback.
    var preparingEpisodeId: String?

    /// Set when a download is blocked because the user is on cellular and the file exceeds the size threshold.
    /// Views observe this to present a confirmation alert.
    var pendingCellularDownload: PodcastEpisode?
    var pendingDownloadSizeMB: Int = 0

    /// User-facing error message shown as an alert when download or playback fails.
    var playerError: String?

    private static let cellularDownloadThreshold: Int64 = 100 * 1024 * 1024

    /// How often to recheck for chapters while an episode plays without them.
    /// Longer than `ChapterDownloadService.minimumCheckInterval` so a scheduled poll
    /// is never thrown away by that throttle.
    private static let chapterFetchInterval: TimeInterval = 10 * 60

    /// Only episodes this recent are watched. An older episode with no chapters has a
    /// permanent gap — generation happens within hours of publication — so polling for
    /// it would never resolve.
    private static let chapterWatchWindow: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Dependencies

    @ObservationIgnored var progressStore: EpisodeProgressStore?
    @ObservationIgnored var bookmarkStore: EpisodeBookmarkStore?
    @ObservationIgnored var listenStore: EpisodeListenStore?
    @ObservationIgnored var playedStore: EpisodePlayedStore?
    @ObservationIgnored var analyticsService: AnalyticsServiceProtocol?
    @ObservationIgnored var chapterDownloadService: ChapterDownloadService?

    /// Set to `true` when a bookmark is added from the lock screen remote command.
    /// Observed by `MainView` to auto-open the Now Playing screen.
    var pendingRemoteBookmark: Bool = false

    var showSupportPrompt: Bool = false
    var dismissNowPlaying: Bool = false

    /// Whether the current episode's chapters are still expected to arrive. Owned by
    /// `syncChapterFetchTimer`; read by the now-playing chapter canvas, whose empty
    /// state would otherwise flatly say the episode has none while we're still
    /// waiting on them.
    var chaptersMayStillArrive: Bool = false

    // MARK: - Private State

    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored private var playbackDelegate: PlaybackDelegate?
    @ObservationIgnored private var timer: Timer?
    /// Separate from `timer`, which is stopped when the app backgrounds.
    @ObservationIgnored private var chapterTimer: Timer?
    /// Rechecks the server while a recent episode plays without chapters yet.
    @ObservationIgnored private var chapterFetchTimer: Timer?
    @ObservationIgnored private let chapterProvider = ChapterProvider()
    @ObservationIgnored private var chapterObserverConfigured = false
    @ObservationIgnored private var activeDownloadTask: URLSessionDownloadTask?
    @ObservationIgnored private var downloadingEpisodeId: String?
    @ObservationIgnored private var playGeneration: Int = 0
    @ObservationIgnored private var remoteCommandsConfigured = false
    @ObservationIgnored private var audioSessionObserversConfigured = false
    @ObservationIgnored private var wasPlayingBeforeInterruption = false
    @ObservationIgnored private var lastProgressSaveTime: Date = .distantPast
    @ObservationIgnored private var currentSessionStart: Date?
    @ObservationIgnored private var currentSessionStartTime: TimeInterval = 0
    @ObservationIgnored private var isSceneActive = true

    @ObservationIgnored private lazy var downloadCoordinator: DownloadCoordinator = {
        DownloadCoordinator { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self, let id = self.downloadingEpisodeId, self.audioPlayer == nil else { return }
                self.downloadProgress[id] = progress
            }
        }
    }()

    @ObservationIgnored private lazy var downloadSession: URLSession = {
        URLSession(
            configuration: .default,
            delegate: downloadCoordinator,
            delegateQueue: nil
        )
    }()

    // MARK: - Public API

    /// Plays the given episode. Downloads it first if not already on disk.
    /// If the same episode is currently loaded, toggles play/pause instead.
    @MainActor
    func play(episode: PodcastEpisode) async {
        if currentEpisode?.id == episode.id && audioPlayer != nil {
            togglePlayPause()
            return
        }

        stopInternal()
        preparingEpisodeId = episode.id
        playGeneration += 1
        let generation = playGeneration

        let fileURL = Self.localFileURL(for: episode)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            preparingEpisodeId = nil
            startPlayback(episode: episode, fileURL: fileURL)
            return
        }

        if await shouldWarnCellularDownload(for: episode) {
            preparingEpisodeId = nil
            return
        }

        await performDownloadAndPlay(episode: episode, generation: generation)
    }

    /// Toggles between playing and paused states.
    @MainActor
    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        if player.isPlaying {
            recordCurrentSession(didComplete: false)
            player.pause()
            isPlaying = false
            stopTimer()
            saveProgress()
        } else {
            beginSession()
            player.play()
            player.rate = playbackSpeed
            isPlaying = true
            if isSceneActive {
                startTimer()
            }
        }
        updateNowPlayingInfo()
    }

    /// Stops playback and clears the current episode.
    @MainActor
    func stop() {
        stopInternal()
    }

    /// Whether the given episode is currently being downloaded.
    func isDownloading(_ episode: PodcastEpisode) -> Bool {
        downloadProgress[episode.id] != nil
    }

    /// Whether the given episode is being prepared (pre-download checks in flight).
    func isPreparing(_ episode: PodcastEpisode) -> Bool {
        preparingEpisodeId == episode.id
    }

    /// Cancels any active episode download.
    @MainActor
    func cancelDownload() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        downloadCoordinator.cancelContinuation()
        preparingEpisodeId = nil
        downloadProgress = [:]
        downloadingEpisodeId = nil
    }

    /// Whether the given episode is the one currently loaded in the player.
    func isCurrentEpisode(_ episode: PodcastEpisode) -> Bool {
        currentEpisode?.id == episode.id
    }

    /// Seeks to the given time, clamped to `0...duration`.
    @MainActor
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let clamped = min(max(time, 0), duration)
        player.currentTime = clamped
        if isSceneActive {
            currentTime = clamped
        }
        updateNowPlayingInfo()
    }

    /// Skips forward by the given number of seconds (default 30).
    @MainActor
    func skipForward(_ seconds: TimeInterval = 30) {
        seek(to: currentPlaybackTime() + seconds)
    }

    /// Skips backward by the given number of seconds (default 15).
    @MainActor
    func skipBackward(_ seconds: TimeInterval = 15) {
        seek(to: currentPlaybackTime() - seconds)
    }

    /// Changes the playback speed and persists the choice.
    @MainActor
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        audioPlayer?.rate = speed
        UserDefaults.standard.set(speed, forKey: "episodePlaybackSpeed")
        updateNowPlayingInfo()
    }

    /// Formats a speed value for display (e.g. 1.0 -> "1x", 1.5 -> "1.5x", 0.75 -> "0.75x").
    static func formattedSpeed(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return "\(Int(speed))x"
        }
        return "\(String(format: "%g", speed))x"
    }

    /// Called by the UI when the user confirms they want to download over cellular.
    @MainActor
    func confirmCellularDownload() async {
        guard let episode = pendingCellularDownload else { return }
        pendingCellularDownload = nil
        pendingDownloadSizeMB = 0

        playGeneration += 1
        let generation = playGeneration
        await performDownloadAndPlay(episode: episode, generation: generation)
    }

    @MainActor
    func dismissCellularDownload() {
        pendingCellularDownload = nil
        pendingDownloadSizeMB = 0
    }

    @MainActor
    func setSceneActive(_ isActive: Bool) {
        guard isSceneActive != isActive else { return }
        isSceneActive = isActive

        if isActive {
            currentTime = currentPlaybackTime()
            if isPlaying {
                startTimer()
            }
        } else {
            currentTime = currentPlaybackTime()
            stopTimer()
            updateNowPlayingInfo()
            saveProgress()
        }
    }

    // MARK: - Cellular Check

    @MainActor
    private func shouldWarnCellularDownload(for episode: PodcastEpisode) async -> Bool {
        let monitor = NWPathMonitor()
        let path = await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path)
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
        }

        guard path.usesInterfaceType(.cellular) else { return false }

        var request = URLRequest(url: episode.audioURL)
        request.httpMethod = "HEAD"

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "0") ?? 0
        guard contentLength > Self.cellularDownloadThreshold else { return false }

        pendingCellularDownload = episode
        pendingDownloadSizeMB = Int(contentLength / (1024 * 1024))
        return true
    }

    @MainActor
    private func performDownloadAndPlay(episode: PodcastEpisode, generation: Int) async {
        do {
            let downloadedURL = try await downloadEpisode(episode)
            guard playGeneration == generation else { return }
            startPlayback(episode: episode, fileURL: downloadedURL)
        } catch is CancellationError {
            guard playGeneration == generation else { return }
            preparingEpisodeId = nil
            downloadProgress = [:]
            downloadingEpisodeId = nil
        } catch {
            guard playGeneration == generation else { return }
            preparingEpisodeId = nil
            downloadProgress = [:]
            downloadingEpisodeId = nil
            playerError = "Não foi possível baixar o episódio. Tente novamente."
        }
    }

    // MARK: - Download

    @MainActor
    private func downloadEpisode(_ episode: PodcastEpisode) async throws -> URL {
        preparingEpisodeId = nil
        downloadingEpisodeId = episode.id
        downloadProgress[episode.id] = 0.0

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: CancellationError())
                return
            }
            self.downloadCoordinator.setContinuation(continuation, episodeId: episode.id)

            let task = self.downloadSession.downloadTask(with: episode.audioURL)
            self.activeDownloadTask = task
            task.resume()
        }
    }

    // MARK: - Playback

    @MainActor
    private func startPlayback(episode: PodcastEpisode, fileURL: URL) {
        preparingEpisodeId = nil
        downloadProgress = [:]
        downloadingEpisodeId = nil

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            playerError = "Não foi possível iniciar a reprodução."
            return
        }

        guard let player = try? AVAudioPlayer(contentsOf: fileURL) else {
            playerError = "Não foi possível iniciar a reprodução."
            return
        }

        let delegate = PlaybackDelegate { [weak self] in
            Task { @MainActor [weak self] in
                self?.onPlaybackFinished()
            }
        }

        audioPlayer = player
        playbackDelegate = delegate
        player.delegate = delegate
        player.enableRate = true
        currentEpisode = episode
        duration = player.duration
        loadChapters(for: episode)

        if let saved = progressStore?.progress(for: episode.id),
           saved.currentTime > 0, saved.currentTime < player.duration {
            player.currentTime = saved.currentTime
            if isSceneActive {
                currentTime = saved.currentTime
            }
        }

        player.play()
        player.rate = playbackSpeed
        isPlaying = true
        beginSession()
        configureRemoteCommands()
        configureAudioSessionObservers()
        configureChapterObserver()
        updateNowPlayingInfo()
        loadArtwork(for: episode)
        if isSceneActive {
            startTimer()
        }

        Task {
            await analyticsService?.send(
                originatingScreen: "EpisodePlayer",
                action: "didPlayEpisode(\(episode.title))"
            )
        }
    }

    @MainActor
    private func onPlaybackFinished() {
        recordCurrentSession(didComplete: true)
        if let id = currentEpisode?.id {
            progressStore?.clear(episodeID: id)
            if !(playedStore?.isPlayed(id) ?? true) {
                playedStore?.toggle(id)
            }
        }

        if let episode = currentEpisode, UserSettings().getAutoDeletePlayedEpisodes() {
            try? FileManager.default.removeItem(at: Self.localFileURL(for: episode))
        }

        isPlaying = false
        currentTime = 0
        duration = 0
        currentEpisode = nil
        stopTimer()
        clearNowPlayingInfo()
        dismissNowPlaying = true

        let memory = AppPersistentMemory.shared
        memory.setEpisodesCompletedCount(memory.getEpisodesCompletedCount() + 1)
        if memory.shouldShowEpisodeSupportPrompt() {
            showSupportPrompt = true
        }
    }

    // MARK: - Timer

    @MainActor
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            let playbackTime = player.currentTime
            if self.isSceneActive {
                self.currentTime = playbackTime
            }
            self.saveProgressThrottled(currentTime: playbackTime)
        }
    }

    @MainActor
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func stopInternal() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        downloadCoordinator.cancelContinuation()
        preparingEpisodeId = nil
        downloadProgress = [:]
        downloadingEpisodeId = nil

        recordCurrentSession(didComplete: false)
        saveProgress()

        audioPlayer?.stop()
        audioPlayer = nil
        playbackDelegate = nil
        isPlaying = false
        currentEpisode = nil
        currentTime = 0
        duration = 0
        stopTimer()
        clearNowPlayingInfo()
    }

    // MARK: - Progress Persistence

    @MainActor
    private func saveProgress() {
        let playbackTime = currentPlaybackTime()
        guard let episode = currentEpisode, playbackTime > 0, duration > 0 else { return }
        progressStore?.save(episodeID: episode.id, currentTime: playbackTime, duration: duration)
        lastProgressSaveTime = Date()
    }

    @MainActor
    private func saveProgressThrottled(currentTime: TimeInterval) {
        guard Date().timeIntervalSince(lastProgressSaveTime) >= 5 else { return }
        guard let episode = currentEpisode, currentTime > 0, duration > 0 else { return }
        progressStore?.save(episodeID: episode.id, currentTime: currentTime, duration: duration)
        lastProgressSaveTime = Date()
    }

    // MARK: - Listen Session Logging

    @MainActor
    private func recordCurrentSession(didComplete: Bool) {
        guard let start = currentSessionStart,
              let episodeId = currentEpisode?.id else { return }
        let now = Date()
        let listened = currentPlaybackTime() - currentSessionStartTime
        guard listened > 0 else { return }
        listenStore?.recordSession(
            episodeId: episodeId,
            startedAt: start,
            endedAt: now,
            durationListened: listened,
            didComplete: didComplete
        )
        currentSessionStart = nil
        currentSessionStartTime = 0
    }

    @MainActor
    private func beginSession() {
        currentSessionStart = Date()
        currentSessionStartTime = currentPlaybackTime()
    }

    // MARK: - Remote Commands

    private func configureRemoteCommands() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipForward() }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipBackward() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor [weak self] in self?.seek(to: positionEvent.positionTime) }
            return .success
        }

        commandCenter.bookmarkCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleRemoteBookmark() }
            return .success
        }
    }

    @MainActor
    private func handleRemoteBookmark() {
        guard let episode = currentEpisode else { return }
        bookmarkStore?.addBookmark(episodeId: episode.id, timestamp: currentPlaybackTime())
        pendingRemoteBookmark = true
    }

    // MARK: - Audio Session Observers

    private func configureAudioSessionObservers() {
        guard !audioSessionObserversConfigured else { return }
        audioSessionObserversConfigured = true

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            switch type {
            case .began:
                self.handleInterruptionBegan()
            case .ended:
                let options = AVAudioSession.InterruptionOptions(
                    rawValue: (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
                )
                self.handleInterruptionEnded(shouldResume: options.contains(.shouldResume))
            @unknown default:
                break
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .oldDeviceUnavailable
            else { return }

            self.handleOldDeviceUnavailable()
        }
    }

    @MainActor
    private func handleInterruptionBegan() {
        guard audioPlayer != nil, isPlaying else { return }
        wasPlayingBeforeInterruption = true
        recordCurrentSession(didComplete: false)
        isPlaying = false
        stopTimer()
        saveProgress()
        updateNowPlayingInfo()
    }

    @MainActor
    private func handleInterruptionEnded(shouldResume: Bool) {
        guard shouldResume, wasPlayingBeforeInterruption, let player = audioPlayer else {
            wasPlayingBeforeInterruption = false
            return
        }
        wasPlayingBeforeInterruption = false
        beginSession()
        player.play()
        player.rate = playbackSpeed
        isPlaying = true
        if isSceneActive {
            startTimer()
        }
        updateNowPlayingInfo()
    }

    @MainActor
    private func handleOldDeviceUnavailable() {
        guard audioPlayer != nil, isPlaying else { return }
        recordCurrentSession(didComplete: false)
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
        saveProgress()
        updateNowPlayingInfo()
    }

    // MARK: - Now Playing Info

    @MainActor
    private func updateNowPlayingInfo() {
        guard let episode = currentEpisode else { return }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()

        // With chapters, the chapter name is the more useful headline and the
        // episode title moves to the artist line so it isn't lost.
        if let chapterTitle = activeChapterTitle() {
            info[MPMediaItemPropertyTitle] = chapterTitle
            info[MPMediaItemPropertyArtist] = episode.title
        } else {
            info[MPMediaItemPropertyTitle] = episode.title
            info[MPMediaItemPropertyArtist] = nil
        }

        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPlaybackTime()
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackSpeed) : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        syncChapterTimer()
        syncChapterFetchTimer()
    }

    // MARK: - Chapters

    /// Title of the chapter covering the current position, or nil when chapters are
    /// unavailable or switched off.
    @MainActor
    private func activeChapterTitle() -> String? {
        guard ChapterPreferences.isEnabled else { return nil }
        return chapterProvider.currentChapter?.title
    }

    @MainActor
    private func loadChapters(for episode: PodcastEpisode) {
        guard ChapterPreferences.isEnabled else { return }
        chapterProvider.load(episodeId: episode.id)
        chapterProvider.update(currentTime: currentPlaybackTime())
    }

    /// Picks up a sync that landed mid-playback. Views watching the same notification
    /// have their own providers; this one backs the lock screen, so without it a
    /// chapter file arriving now wouldn't reach the system player until the next play.
    private func configureChapterObserver() {
        guard !chapterObserverConfigured else { return }
        chapterObserverConfigured = true

        NotificationCenter.default.addObserver(
            forName: ChapterDownloadService.chaptersDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let episode = self.currentEpisode else { return }
                self.loadChapters(for: episode)
                self.updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Chapter Watch

    /// Whether the current episode is one whose chapters could still show up.
    ///
    /// Chapters are generated from the transcript some time after an episode goes out,
    /// so someone who starts listening right away begins with none. Recent enough that
    /// generation is plausibly still pending, with none loaded yet, means "not here
    /// *yet*" rather than "never".
    @MainActor
    private var isRecentEpisodeWithoutChapters: Bool {
        guard ChapterPreferences.isEnabled, !chapterProvider.hasChapters else { return false }
        guard let episode = currentEpisode else { return false }
        return Date().timeIntervalSince(episode.pubDate) < Self.chapterWatchWindow
    }

    /// Keeps the recheck timer running for exactly as long as it's worth rechecking.
    /// Called from `updateNowPlayingInfo`, so every playback state change — including
    /// the chapter reload above, which flips `hasChapters` — re-evaluates it.
    @MainActor
    private func syncChapterFetchTimer() {
        chaptersMayStillArrive = isRecentEpisodeWithoutChapters

        // The timer, unlike the flag, also stops when playback does — there's no lock
        // screen title to keep current for an episode that isn't playing. Resuming
        // restarts it, since this runs on every playback state change.
        guard chaptersMayStillArrive, isPlaying else {
            stopChapterFetchTimer()
            return
        }
        guard chapterFetchTimer == nil else { return }

        // The local file can already be stale at this point — it was last checked when
        // the app launched, possibly before this episode existed.
        checkForNewChapters()

        chapterFetchTimer = Timer.scheduledTimer(
            withTimeInterval: Self.chapterFetchInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForNewChapters()
            }
        }
    }

    @MainActor
    private func stopChapterFetchTimer() {
        chapterFetchTimer?.invalidate()
        chapterFetchTimer = nil
    }

    /// Costs a few hundred bytes unless the catalog actually changed. A sync that does
    /// bring in a new file posts `chaptersDidUpdate`, which loads it and stops this timer.
    @MainActor
    private func checkForNewChapters() {
        guard let chapterDownloadService else { return }
        Task {
            await chapterDownloadService.syncIfNeeded(
                minimumInterval: ChapterDownloadService.minimumCheckInterval
            )
        }
    }

    /// Runs while playing — including in the background, unlike the UI timer, since
    /// the lock screen is exactly where a stale chapter title would show.
    ///
    /// Polling rather than scheduling one fire per boundary: a scheduled fire would
    /// have to be recomputed on every seek and speed change, and this costs a binary
    /// search over a few dozen entries once a second.
    @MainActor
    private func syncChapterTimer() {
        guard ChapterPreferences.isEnabled, isPlaying, chapterProvider.hasChapters else {
            stopChapterTimer()
            return
        }
        guard chapterTimer == nil else { return }

        chapterTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshActiveChapter()
            }
        }
    }

    @MainActor
    private func stopChapterTimer() {
        chapterTimer?.invalidate()
        chapterTimer = nil
    }

    /// Pushes a new title to the system player only when a boundary was crossed —
    /// `ChapterProvider` returns early otherwise.
    @MainActor
    private func refreshActiveChapter() {
        guard let player = audioPlayer else { return }

        let previous = chapterProvider.currentChapter
        chapterProvider.update(currentTime: player.currentTime)
        guard chapterProvider.currentChapter != previous else { return }

        guard let episode = currentEpisode else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        if let chapterTitle = activeChapterTitle() {
            info[MPMediaItemPropertyTitle] = chapterTitle
            info[MPMediaItemPropertyArtist] = episode.title
        } else {
            info[MPMediaItemPropertyTitle] = episode.title
            info[MPMediaItemPropertyArtist] = nil
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    @MainActor
    private func currentPlaybackTime() -> TimeInterval {
        audioPlayer?.currentTime ?? currentTime
    }

    @MainActor
    private func clearNowPlayingInfo() {
        stopChapterTimer()
        stopChapterFetchTimer()
        chaptersMayStillArrive = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Artwork

    private func loadArtwork(for episode: PodcastEpisode) {
        guard let imageURL = episode.imageURL else { return }
        Task.detached { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: imageURL),
                  let image = UIImage(data: data) else { return }

            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

            await MainActor.run { [weak self] in
                guard let self, self.currentEpisode?.id == episode.id else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }

    // MARK: - File Management

    static func localFileURL(for episode: PodcastEpisode) -> URL {
        let filename = sanitizedFilename(for: episode.id)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("\(InternalFolderNames.downloadedEpisodes)\(filename).mp3")
    }

    static func isDownloaded(_ episode: PodcastEpisode) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(for: episode).path)
    }

    static func sanitizedFilename(for episodeId: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return episodeId.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
    }
}

// MARK: - Download Coordinator

extension EpisodePlayer {

    /// Coordinates `URLSessionDownloadTask` callbacks, tracking progress and bridging
    /// the delegate pattern with async/await via `CheckedContinuation`.
    final class DownloadCoordinator: NSObject, URLSessionDownloadDelegate {

        private let onProgress: (Double) -> Void
        private let lock = NSLock()
        private var continuation: CheckedContinuation<URL, Error>?
        private var episodeId: String?

        init(onProgress: @escaping (Double) -> Void) {
            self.onProgress = onProgress
        }

        func setContinuation(_ continuation: CheckedContinuation<URL, Error>, episodeId: String) {
            lock.lock()
            self.continuation?.resume(throwing: CancellationError())
            self.continuation = continuation
            self.episodeId = episodeId
            lock.unlock()
        }

        func cancelContinuation() {
            lock.lock()
            continuation?.resume(throwing: CancellationError())
            continuation = nil
            episodeId = nil
            lock.unlock()
        }

        // MARK: URLSessionDownloadDelegate

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            guard totalBytesExpectedToWrite > 0 else { return }
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress(progress)
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
            lock.lock()
            guard let episodeId, let activeContinuation = continuation else {
                lock.unlock()
                return
            }
            continuation = nil
            self.episodeId = nil
            lock.unlock()

            let filename = EpisodePlayer.sanitizedFilename(for: episodeId)
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsURL.appendingPathComponent(
                "\(InternalFolderNames.downloadedEpisodes)\(filename).mp3"
            )

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: location, to: destinationURL)
                activeContinuation.resume(returning: destinationURL)
            } catch {
                activeContinuation.resume(throwing: error)
            }
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: Error?
        ) {
            guard let error else { return }
            lock.lock()
            continuation?.resume(throwing: error)
            continuation = nil
            lock.unlock()
        }
    }
}

// MARK: - Playback Delegate

extension EpisodePlayer {

    /// Receives `AVAudioPlayerDelegate` callbacks and forwards them via a closure.
    final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {

        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            onFinish()
        }
    }
}
