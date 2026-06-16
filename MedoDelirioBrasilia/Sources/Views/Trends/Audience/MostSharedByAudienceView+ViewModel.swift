//
//  MostSharedByAudienceViewViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 11/10/22.
//

import Foundation
import SwiftUI

extension MostSharedByAudienceView {

    @Observable class ViewModel {

        var soundsState: LoadingState<[TopChartItem]> = .loading
        var soundsTimeInterval: TrendsTimeInterval = TrendsService.defaultSoundsTimeInterval
        var soundsLastCheckDate: Date = Date(timeIntervalSince1970: 0)
        var soundsLastCheckString: String = ""

        var songsState: LoadingState<[TopChartItem]> = .loading
        var songsTimeInterval: TrendsTimeInterval = TrendsService.defaultSongsTimeInterval
        var songsLastCheckDate: Date = Date(timeIntervalSince1970: 0)
        var songsLastCheckString: String = ""

        var reactionsState: LoadingState<[TopChartReaction]> = .loading
        var reactionsLastCheckDate: Date = Date(timeIntervalSince1970: 0)
        var reactionsLastCheckString: String = ""

        var lastTimePulledDownToRefresh: Date = Date(timeIntervalSince1970: 0)

        var currentActivity: NSUserActivity?

        // Alerts
        var alertTitle: String = ""
        var alertMessage: String = ""
        var showAlert: Bool = false

        var displayToast: ((String) -> Void) = { _ in }

        private let lastCheckText: String = "Última consulta: "
        private let unavailableText: String = "indisponível"
        private let justNowText: String = "agora mesmo"

        private let trendsService: TrendsServiceProtocol

        init(
            trendsService: TrendsServiceProtocol
        ) {
            self.trendsService = trendsService
        }
    }
}

// MARK: - Internal Functions

extension MostSharedByAudienceView.ViewModel {

    private func loadAll(
        didPullDownToRefresh: Bool = false
    ) async {
        // Check if enough time has passed for a retry
        if didPullDownToRefresh, !lastTimePulledDownToRefresh.minutesPassed(1) {
            displayToast(
                String(format: Shared.Sync.waitMessage, lastTimePulledDownToRefresh.minutesAndSecondsFromNow)
            )
            return
        }

        if didPullDownToRefresh {
            lastTimePulledDownToRefresh = .now
        }

        // Send user stats and retrieve remote stats
        let result = await Podium.shared.sendShareCountStatsToServer()

        guard result == .successful || result == .noStatsToSend else {
            await MainActor.run {
                self.soundsState = .error("")
                self.songsState = .error("")
                self.showServerUnavailableAlert()
            }
            return
        }

        await loadSoundsList()
        await loadSongsList()
        await loadReactionsGrid()
    }

    private func loadSoundsList() async {
        soundsState = .loading
        do {
            let soundRanking = try await trendsService.shareCountStats(
                for: .sounds,
                in: soundsTimeInterval
            ).ranked

            soundsState = .loaded(soundRanking)

            soundsLastCheckDate = .now
            updateSoundsLastUpdatedAtString()
        } catch {
            print(error)
            soundsState = .error(error.localizedDescription)
        }
    }

    private func loadSongsList() async {
        songsState = .loading
        do {
            let songRanking = try await trendsService.shareCountStats(
                for: .songs,
                in: songsTimeInterval
            ).ranked

            songsState = .loaded(songRanking)

            songsLastCheckDate = .now
            updateSongsLastUpdatedAtString()
        } catch {
            print(error)
            songsState = .error(error.localizedDescription)
        }
    }

    private func loadReactionsGrid() async {
        reactionsState = .loading
        do {
            let ranking = try await trendsService.reactionsStats()
            reactionsState = .loaded(ranking)

            reactionsLastCheckDate = .now
            updateReactionsLastUpdatedAtString()
        } catch {
            print(error)
            reactionsState = .error(error.localizedDescription)
        }
    }

    private func updateSoundsLastUpdatedAtString() {
        if soundsLastCheckDate == Date(timeIntervalSince1970: 0) {
            soundsLastCheckString = lastCheckText + unavailableText
        } else if soundsLastCheckDate.minutesPassed(1) {
            soundsLastCheckString = lastCheckText + soundsLastCheckDate.asRelativeDateTime
        } else {
            soundsLastCheckString = lastCheckText + justNowText
        }
    }

    private func updateSongsLastUpdatedAtString() {
        if songsLastCheckDate == Date(timeIntervalSince1970: 0) {
            songsLastCheckString = lastCheckText + unavailableText
        } else if songsLastCheckDate.minutesPassed(1) {
            songsLastCheckString = lastCheckText + songsLastCheckDate.asRelativeDateTime
        } else {
            songsLastCheckString = lastCheckText + justNowText
        }
    }

    private func updateReactionsLastUpdatedAtString() {
        if reactionsLastCheckDate == Date(timeIntervalSince1970: 0) {
            reactionsLastCheckString = lastCheckText + unavailableText
        } else if reactionsLastCheckDate.minutesPassed(1) {
            reactionsLastCheckString = lastCheckText + reactionsLastCheckDate.asRelativeDateTime
        } else {
            reactionsLastCheckString = lastCheckText + justNowText
        }
    }

    private func showServerUnavailableAlert() {
        HapticFeedback.error()
        alertTitle = "Servidor Indisponível"
        alertMessage = "Não foi possível obter o ranking mais recente. Tente novamente mais tarde."
        showAlert = true
    }

    private func donateActivity(forTimeInterval timeIntervalOption: TrendsTimeInterval) {
        var activityType = ""
        var activityName = ""

        switch timeIntervalOption {
        case .last24Hours:
            activityType = Shared.ActivityTypes.viewLast24HoursTopChart
            activityName = "Ver vírgulas mais compartilhadas nas últimas 24 horas"
        case .last3Days:
            activityType = Shared.ActivityTypes.viewLast24HoursTopChart
            activityName = "Ver vírgulas mais compartilhadas nos últimos 3 dias"
        case .lastWeek:
            activityType = Shared.ActivityTypes.viewLastWeekTopChart
            activityName = "Ver vírgulas mais compartilhadas na última semana"
        case .lastMonth:
            activityType = Shared.ActivityTypes.viewLastMonthTopChart
            activityName = "Ver vírgulas mais compartilhadas no último mês"
        case .last3Months:
            activityType = Shared.ActivityTypes.viewLastMonthTopChart
            activityName = ""
        case .year2026:
            activityType = Shared.ActivityTypes.view2026TopChart
            activityName = "Ver vírgulas mais compartilhadas de 2026"
        case .year2025:
            activityType = Shared.ActivityTypes.view2025TopChart
            activityName = "Ver vírgulas mais compartilhadas de 2025"
        case .year2024:
            activityType = Shared.ActivityTypes.view2024TopChart
            activityName = "Ver vírgulas mais compartilhadas de 2024"
        case .year2023:
            activityType = Shared.ActivityTypes.view2023TopChart
            activityName = "Ver vírgulas mais compartilhadas de 2023"
        case .year2022:
            activityType = Shared.ActivityTypes.view2022TopChart
            activityName = "Ver vírgulas mais compartilhadas de 2022"
        case .allTime:
            activityType = Shared.ActivityTypes.viewAllTimeTopChart
            activityName = "Ver vírgulas mais compartilhadas de todos os tempos"
        }

        self.currentActivity = UserActivityWaiter.getDonatableActivity(withType: activityType, andTitle: activityName)
        self.currentActivity?.becomeCurrent()
    }
}

// MARK: - User Actions

extension MostSharedByAudienceView.ViewModel {

    public func onViewAppeared() async {
        if soundsState == .loading {
            await loadAll()
            donateActivity(forTimeInterval: soundsTimeInterval)
        } else if soundsLastCheckDate.minutesPassed(60) {
            await loadAll()
        }
    }

    public func onScenePhaseChanged(isNewPhaseActive: Bool) async {
        if isNewPhaseActive, soundsLastCheckDate.minutesPassed(60) {
            await loadAll()
        }
    }

    public func onSoundsSelectedTimeIntervalChanged(newTimeInterval: TrendsTimeInterval) async {
        await loadSoundsList()
        donateActivity(forTimeInterval: newTimeInterval)
    }

    public func onSongsSelectedTimeIntervalChanged(newTimeInterval: TrendsTimeInterval) async {
        await loadSongsList()
        //donateActivity(forTimeInterval: newTimeInterval) // TODO: Adapt for Songs.
    }

    public func onPullToRefreshLists() async {
        await loadAll(didPullDownToRefresh: true)
    }

    public func onReloadPopularReactionsSelected() async {
        await loadReactionsGrid()
    }

    public func onLastCheckStringUpdatingTimerFired() {
        updateSoundsLastUpdatedAtString()
        updateSongsLastUpdatedAtString()
        updateReactionsLastUpdatedAtString()
    }
}
