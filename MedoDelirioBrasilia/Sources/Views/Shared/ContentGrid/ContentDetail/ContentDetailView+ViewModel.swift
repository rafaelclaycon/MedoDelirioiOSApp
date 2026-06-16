//
//  ContentDetailView+ViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 23/11/24.
//

import SwiftUI

extension ContentDetailView {

    @MainActor
    @Observable
    final class ViewModel {

        internal let content: AnyEquatableMedoContent
        private let openAuthorDetailsAction: (Author) -> Void
        internal let authorId: String?
        private let openReactionAction: (Reaction) -> Void
        private let reactionId: String?
        private let dismissAction: () -> Void

        var isPlaying: Bool = false
        var soundStatistics: ContentStatisticsState<ContentShareCountStats> = .loading
        var reactionsState: LoadingState<[Reaction]> = .loading

        var toast: Toast?

        // Alerts
        var alertTitle: String = ""
        var alertMessage: String = ""
        var showAlert: Bool = false

        // MARK: - Initializer

        init(
            content: AnyEquatableMedoContent,
            openAuthorDetailsAction: @escaping (Author) -> Void,
            authorId: String?,
            openReactionAction: @escaping (Reaction) -> Void,
            reactionId: String?,
            dismissAction: @escaping () -> Void
        ) {
            self.content = content
            self.openAuthorDetailsAction = openAuthorDetailsAction
            self.authorId = authorId
            self.openReactionAction = openReactionAction
            self.reactionId = reactionId
            self.dismissAction = dismissAction
        }
    }
}

// MARK: - User Actions

extension ContentDetailView.ViewModel {

    func onViewLoaded() async {
        await loadStatistics()
        await loadReactions()
    }

    func onPlaySoundSelected() {
        play(content)
    }

    func onAuthorSelected() {
        guard
            !content.authorId.isEmpty,
            let author = try? LocalDatabase.shared.author(withId: content.authorId)
        else { return }
        openAuthorDetailsAction(author)
    }

    func onEditAuthorSelected() async {
        await Mailman.openDefaultEmailApp(
            subject: String(format: Shared.suggestOtherAuthorNameEmailSubject, content.title),
            body: String(format: Shared.suggestOtherAuthorNameEmailBody, content.subtitle, content.id)
        )
    }

    func onRetryLoadStatisticsSelected() async {
        await loadStatistics()
    }

    func onReactionSelected(reaction: Reaction) {
        if reaction.id == reactionId {
            dismissAction()
        } else {
            openReactionAction(reaction)
        }
    }

    func onSuggestAddToReactionSelected() async {
        await Mailman.openDefaultEmailApp(
            subject: String(format: "Sugestão Para Adicionar '%@' a Uma Reação", content.title),
            body: String(format: "As Reações expressam emoções, acontecimentos ou personalidades. Qual o nome da Reação nova ou existente na qual você acha que esse conteúdo se encaixa?")
        )
    }

    func onRetryLoadReactionsSelected() async {
        await loadReactions()
    }

    func onSoundIdSelected() {
        UIPasteboard.general.string = content.id
        toast = Toast(
            message: "ID do som copiado com sucesso!",
            type: .success
        )
    }
}

// MARK: - Internal Functions

extension ContentDetailView.ViewModel {

    private func play(_ content: AnyEquatableMedoContent) {
        do {
            let url = try content.fileURL()

            isPlaying = true

            AudioPlayer.shared = AudioPlayer(url: url, update: { state in
                if state?.activity == .stopped {
                    self.isPlaying = false
                }
            })

            AudioPlayer.shared?.togglePlay()
        } catch {
            if content.isFromServer ?? false {
                showServerSoundNotAvailableAlert()
            } else {
                showUnableToGetSoundAlert()
            }
        }
    }

    private func loadStatistics() async {
        soundStatistics = .loading
        let url = URL(string: APIClient.shared.serverPath + "v3/sound-share-count-stats-for/\(content.id)")!
        do {
            let stats: ContentShareCountStats = try await APIClient.shared.get(from: url)
            soundStatistics = .loaded(stats)
        } catch APIClientError.resourceNotFound {
            soundStatistics = .noDataYet
        } catch {
            debugPrint(error.localizedDescription)
            soundStatistics = .error(error.localizedDescription)
        }
    }

    private func loadReactions() async {
        reactionsState = .loading
        let url = URL(string: APIClient.shared.serverPath + "v4/reactions-for-sound/\(content.id)")!
        do {
            var reactions: [ReactionDTO] = try await APIClient.shared.get(from: url)
            reactions.sort(by: { $0.position < $1.position })
            reactionsState = .loaded(reactions.map { Reaction(dto: $0, type: .regular) })
        } catch {
            debugPrint(error.localizedDescription)
            reactionsState = .error(error.localizedDescription)
        }
    }

    private func showUnableToGetSoundAlert() {
        HapticFeedback.error()
        alertTitle = Shared.contentNotFoundAlertTitle(content.title)
        alertMessage = Shared.contentNotFoundAlertMessage
        showAlert = true
    }

    private func showServerSoundNotAvailableAlert() {
        HapticFeedback.error()
        alertTitle = Shared.contentNotFoundAlertTitle(content.title)
        alertMessage = Shared.serverContentNotAvailableMessage
        showAlert = true
    }
}
