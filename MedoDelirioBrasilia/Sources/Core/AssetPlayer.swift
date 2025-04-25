//
//  AssetPlayer.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 08/12/24.
//

import AVFoundation
import MediaPlayer

class AssetPlayer {

    // Possible values of the `playerState` property.

    enum PlayerState {
        case stopped
        case playing
        case paused
    }

    // The app-supplied object that provides `NowPlayable`-conformant behavior.

    let nowPlayableBehavior: NowPlayable

    // The player actually being used for playback. An app may use any system-provided
    // player, or may play content in any way that is wishes, provided that it uses
    // the NowPlayable behavior correctly.

    let player: AVQueuePlayer

    // A playlist of items to play.

    public var playerItems: [AVPlayerItem]

    // Metadata for each item.

    public var staticMetadatas: [NowPlayableStaticMetadata]

    // The internal state of this AssetPlayer separate from the state
    // of its AVQueuePlayer.

    private var playerState: PlayerState = .stopped {
        didSet {
            #if os(macOS)
            NSLog("%@", "**** Set player state \(playerState), playbackState \(MPNowPlayingInfoCenter.default().playbackState.rawValue)")
            #else
            NSLog("%@", "**** Set player state \(playerState)")
            #endif
        }
    }

    // `true` if the current session has been interrupted by another app.

    private var isInterrupted: Bool = false

    // Private observers of notifications and property changes.

    private var itemObserver: NSKeyValueObservation!
    private var rateObserver: NSKeyValueObservation!
    private var statusObserver: NSObjectProtocol!

    // A shorter name for a very long property name.

    private static let mediaSelectionKey = "availableMediaCharacteristicsWithMediaSelectionOptions"

    // Initialize a new `AssetPlayer` object.

    init() throws {
        self.nowPlayableBehavior = IOSNowPlayableBehavior()

        // Get the subset of assets that the configuration actually wants to play,
        // and use it to construct the playlist.

//        let playableAssets = ConfigModel.shared.assets.compactMap { $0.shouldPlay ? $0 : nil }
//
//        self.staticMetadatas = playableAssets.map { $0.metadata }
//        self.playerItems = playableAssets.map {
//            AVPlayerItem(asset: $0.urlAsset, automaticallyLoadedAssetKeys: [AssetPlayer.mediaSelectionKey])
//        }
        self.staticMetadatas = []
        self.playerItems = []

        // Create a player, and configure it for external playback, if the
        // configuration requires.

        self.player = AVQueuePlayer()
        player.allowsExternalPlayback = true

        // Construct lists of commands to be registered or disabled.

//        var registeredCommands = [] as [NowPlayableCommand]
        var enabledCommands = [] as [NowPlayableCommand]

        // Arrange the commands into collections.

        let collection1 = [ConfigCommand(.pause, "Pause"),
                           ConfigCommand(.play, "Play"),
                           ConfigCommand(.stop, "Stop"),
                           ConfigCommand(.togglePausePlay, "Play/Pause")]
        let collection2 = [ConfigCommand(.nextTrack, "Next Track"),
                           ConfigCommand(.previousTrack, "Previous Track"),
                           ConfigCommand(.changeRepeatMode, "Repeat Mode"),
                           ConfigCommand(.changeShuffleMode, "Shuffle Mode")]
        let collection3 = [ConfigCommand(.changePlaybackRate, "Playback Rate"),
                           ConfigCommand(.seekBackward, "Seek Backward"),
                           ConfigCommand(.seekForward, "Seek Forward"),
                           ConfigCommand(.skipBackward, "Skip Backward"),
                           ConfigCommand(.skipForward, "Skip Forward"),
                           ConfigCommand(.changePlaybackPosition, "Playback Position")]
        let collection4 = [ConfigCommand(.rating, "Rating"),
                           ConfigCommand(.like, "Like"),
                           ConfigCommand(.dislike, "Dislike")]
        let collection5 = [ConfigCommand(.bookmark, "Bookmark")]
        let collection6 = [ConfigCommand(.enableLanguageOption, "Enable Language Option"),
                           ConfigCommand(.disableLanguageOption, "Disable Language Option")]

        // Create the collections.

        var registeredCommands = nowPlayableBehavior.defaultRegisteredCommands
        var disabledCommands = nowPlayableBehavior.defaultDisabledCommands

        let commandCollections = [
            ConfigCommandCollection("Playback", commands: collection1, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Navigating Between Tracks", commands: collection2, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Navigating Track Contents", commands: collection3, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Rating Media Items", commands: collection4, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Bookmarking Media Items", commands: collection5, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Enabling Language Options", commands: collection6, registered: registeredCommands, disabled: disabledCommands)
        ]

        for group in commandCollections {
            registeredCommands.append(contentsOf: group.commands.compactMap { $0.shouldRegister ? $0.command : nil })
            enabledCommands.append(contentsOf: group.commands.compactMap { $0.shouldDisable ? $0.command : nil })
        }

        // Configure the app for Now Playing Info and Remote Command Center behaviors.

        try nowPlayableBehavior.handleNowPlayableConfiguration(
            commands: registeredCommands,
            disabledCommands: enabledCommands,
            commandHandler: handleCommand(command:event:),
            interruptionHandler: handleInterrupt(with:)
        )

        // Start playing, if there is something to play.

//        if !playerItems.isEmpty {
//            // Start a playback session.
//
//            try nowPlayableBehavior.handleNowPlayableSessionStart()
//
//            // Observe changes to the current item and playback rate.
//
//            if player.currentItem != nil {
//
//                itemObserver = player.observe(\.currentItem, options: .initial) {
//                    [unowned self] _, _ in
//                    self.handlePlayerItemChange()
//                }
//
//                rateObserver = player.observe(\.rate, options: .initial) {
//                    [unowned self] _, _ in
//                    self.handlePlaybackChange()
//                }
//
//                statusObserver = player.observe(\.currentItem?.status, options: .initial) {
//                    [unowned self] _, _ in
//                    self.handlePlaybackChange()
//                }
//            }
//
//            // Start the player.
//
//            play()
//        }
    }

    // Stop the playback session.

    func optOut() {
        itemObserver = nil
        rateObserver = nil
        statusObserver = nil

        player.pause()
        player.removeAllItems()
        playerState = .stopped

        nowPlayableBehavior.handleNowPlayableSessionEnd()
    }

    // MARK: Now Playing Info

    // Helper method: update Now Playing Info when the current item changes.

    private func handlePlayerItemChange() {
        guard playerState != .stopped else { return }

        // Find the current item.

        guard let currentItem = player.currentItem else { optOut(); return }
        guard let currentIndex = playerItems.firstIndex(where: { $0 == currentItem }) else { return }

        // Set the Now Playing Info from static item metadata.

        let metadata = staticMetadatas[currentIndex]

        nowPlayableBehavior.handleNowPlayableItemChange(metadata: metadata)
    }

    // Helper method: update Now Playing Info when playback rate or position changes.

    private func handlePlaybackChange() {
        guard playerState != .stopped else { return }

        // Find the current item.

        guard let currentItem = player.currentItem else { optOut(); return }
        guard currentItem.status == .readyToPlay else { return }

        // Create language option groups for the asset's media selection,
        // and determine the current language option in each group, if any.

        // Note that this is a simple example of how to create language options.
        // More sophisticated behavior (including default values, and carrying
        // current values between player tracks) can be implemented by building
        // on the techniques shown here.

        let asset = currentItem.asset

        var languageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup] = []
        var currentLanguageOptions: [MPNowPlayingInfoLanguageOption] = []

        if asset.statusOfValue(forKey: AssetPlayer.mediaSelectionKey, error: nil) == .loaded {

            // Examine each media selection group.

            for mediaCharacteristic in asset.availableMediaCharacteristicsWithMediaSelectionOptions {
                guard mediaCharacteristic == .audible || mediaCharacteristic == .legible,
                    let mediaSelectionGroup = asset.mediaSelectionGroup(forMediaCharacteristic: mediaCharacteristic) else { continue }

                // Make a corresponding language option group.

                let languageOptionGroup = mediaSelectionGroup.makeNowPlayingInfoLanguageOptionGroup()
                languageOptionGroups.append(languageOptionGroup)

                // If the media selection group has a current selection,
                // create a corresponding language option.

                if let selectedMediaOption = currentItem.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup),
                    let currentLanguageOption = selectedMediaOption.makeNowPlayingInfoLanguageOption() {
                    currentLanguageOptions.append(currentLanguageOption)
                }
            }
        }

        // Construct the dynamic metadata, including language options for audio,
        // subtitle and closed caption tracks that can be enabled for the
        // current asset.

        let isPlaying = playerState == .playing
        let metadata = NowPlayableDynamicMetadata(
            rate: player.rate,
            position: Float(currentItem.currentTime().seconds),
            duration: Float(currentItem.duration.seconds),
            currentLanguageOptions: currentLanguageOptions,
            availableLanguageOptionGroups: languageOptionGroups
        )

        nowPlayableBehavior.handleNowPlayablePlaybackChange(playing: isPlaying, metadata: metadata)
    }

    // MARK: Playback Control

    // The following methods handle various playback conditions triggered by remote commands.

    public func play() {
        switch playerState {

        case .stopped:
            playerState = .playing
            player.play()

            handlePlayerItemChange()

        case .playing:
            break

        case .paused where isInterrupted:
            playerState = .playing

        case .paused:
            playerState = .playing
            player.play()
        }
    }

    private func pause() {

        switch playerState {

        case .stopped:
            break

        case .playing where isInterrupted:
            playerState = .paused

        case .playing:
            playerState = .paused
            player.pause()

        case .paused:
            break
        }
    }

    private func togglePlayPause() {

        switch playerState {

        case .stopped:
            play()

        case .playing:
            pause()

        case .paused:
            play()
        }
    }

    private func nextTrack() {

        if case .stopped = playerState { return }

        player.advanceToNextItem()
    }

    private func previousTrack() {

        if case .stopped = playerState { return }

        let currentTime = player.currentTime().seconds
        let currentItems = player.items()
        let previousIndex = playerItems.count - currentItems.count - 1

        guard currentTime < 3, previousIndex > 0, previousIndex < playerItems.count else { seek(to: .zero); return }

        player.removeAllItems()

        for playerItem in playerItems[(previousIndex - 1)...] {

            if player.canInsert(playerItem, after: nil) {
                player.insert(playerItem, after: nil)
            }
        }

        if case .playing = playerState {
            player.play()
        }
    }

    private func seek(to time: CMTime) {

        if case .stopped = playerState { return }

        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) {
            isFinished in
            if isFinished {
                self.handlePlaybackChange()
            }
        }
    }

    private func seek(to position: TimeInterval) {
        seek(to: CMTime(seconds: position, preferredTimescale: 1))
    }

    private func skipForward(by interval: TimeInterval) {
        seek(to: player.currentTime() + CMTime(seconds: interval, preferredTimescale: 1))
    }

    private func skipBackward(by interval: TimeInterval) {
        seek(to: player.currentTime() - CMTime(seconds: interval, preferredTimescale: 1))
    }

    private func setPlaybackRate(_ rate: Float) {

        if case .stopped = playerState { return }

        player.rate = rate
    }

    private func didEnableLanguageOption(_ languageOption: MPNowPlayingInfoLanguageOption) -> Bool {

        guard let currentItem = player.currentItem else { return false }
        guard let (mediaSelectionOption, mediaSelectionGroup) = enabledMediaSelection(for: languageOption) else { return false }

        currentItem.select(mediaSelectionOption, in: mediaSelectionGroup)
        handlePlaybackChange()

        return true
    }

    private func didDisableLanguageOption(_ languageOption: MPNowPlayingInfoLanguageOption) -> Bool {

        guard let currentItem = player.currentItem else { return false }
        guard let mediaSelectionGroup = disabledMediaSelection(for: languageOption) else { return false }

        guard mediaSelectionGroup.allowsEmptySelection else { return false }
        currentItem.select(nil, in: mediaSelectionGroup)
        handlePlaybackChange()

        return true
    }

    // Helper method to get the media selection group and media selection for enabling a language option.

    private func enabledMediaSelection(for languageOption: MPNowPlayingInfoLanguageOption) -> (AVMediaSelectionOption, AVMediaSelectionGroup)? {

        // In your code, you would implement your logic for choosing a media selection option
        // from a suitable media selection group.

        // Note that, when the current track is being played remotely via AirPlay, the language option
        // may not exactly match an option in your local asset's media selection. You may need to consider
        // an approximate comparison algorithm to determine the nearest match.

        // If you cannot find an exact or approximate match, you should return `nil` to ignore the
        // enable command.

        return nil
    }

    // Helper method to get the media selection group for disabling a language option`.

    private func disabledMediaSelection(for languageOption: MPNowPlayingInfoLanguageOption) -> AVMediaSelectionGroup? {

        // In your code, you would implement your logic for finding the media selection group
        // being disabled.

        // Note that, when the current track is being played remotely via AirPlay, the language option
        // may not exactly determine a media selection group in your local asset. You may need to consider
        // an approximate comparison algorithm to determine the nearest match.

        // If you cannot find an exact or approximate match, you should return `nil` to ignore the
        // disable command.

        return nil
    }

    // MARK: Remote Commands

    // Handle a command registered with the Remote Command Center.

    private func handleCommand(command: NowPlayableCommand, event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {

        switch command {

        case .pause:
            pause()

        case .play:
            play()

        case .stop:
            optOut()

        case .togglePausePlay:
            togglePlayPause()

        case .nextTrack:
            nextTrack()

        case .previousTrack:
            previousTrack()

        case .changePlaybackRate:
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            setPlaybackRate(event.playbackRate)

        case .seekBackward:
            guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
            setPlaybackRate(event.type == .beginSeeking ? -3.0 : 1.0)

        case .seekForward:
            guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
            setPlaybackRate(event.type == .beginSeeking ? 3.0 : 1.0)

        case .skipBackward:
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            skipBackward(by: event.interval)

        case .skipForward:
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            skipForward(by: event.interval)

        case .changePlaybackPosition:
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            seek(to: event.positionTime)

        case .enableLanguageOption:
            guard let event = event as? MPChangeLanguageOptionCommandEvent else { return .commandFailed }
            guard didEnableLanguageOption(event.languageOption) else { return .noActionableNowPlayingItem }

        case .disableLanguageOption:
            guard let event = event as? MPChangeLanguageOptionCommandEvent else { return .commandFailed }
            guard didDisableLanguageOption(event.languageOption) else { return .noActionableNowPlayingItem }

        default:
            break
        }

        return .success
    }

    // MARK: Interruptions

    // Handle a session interruption.

    private func handleInterrupt(with interruption: NowPlayableInterruption) {

        switch interruption {

        case .began:
            isInterrupted = true

        case .ended(let shouldPlay):
            isInterrupted = false

            switch playerState {

            case .stopped:
                break

            case .playing where shouldPlay:
                player.play()

            case .playing:
                playerState = .paused

            case .paused:
                break
            }

        case .failed(let error):
            print(error.localizedDescription)
            optOut()
        }
    }
}
