//
//  ReactionsView+ViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI

extension ReactionsView {

    @Observable class ViewModel {

        var state: LoadingState<ReactionGroup> = .loading
        var showHowReactionsWorkSheet: Bool = false
        var showAddStuffSheet: Bool = false

        var showIssueSavingPinAlert: Bool = false
        var showIssueRemovingPinAlert: Bool = false
        var showIssueOpeningReaction: Bool = false

        /// For navigating from Trends
        var reactionIdToOpenAfterLoading = ""
        var reactionToOpen: Reaction? = nil

        private var currentActivity: NSUserActivity?

        private let reactionRepository: ReactionRepositoryProtocol

        // MARK: - Initializer

        init(
            reactionRepository: ReactionRepositoryProtocol
        ) {
            self.reactionRepository = reactionRepository
        }
    }
}

// MARK: - User Actions

extension ReactionsView.ViewModel {

    public func onViewLoaded() async {
        await loadReactions()
        donateActivity()
    }

    public func onTryAgainSelected() async {
        await loadReactions()
    }

    public func onPullToRefresh() async {
        await loadReactions()
    }

    public func onPinReactionSelected(reaction: Reaction) async {
        do {
            try reactionRepository.savePin(reaction: reaction)
            addToPinned(reaction: reaction)

            await AnalyticsService().send(
                originatingScreen: "ReactionsView",
                action: "pinnedReaction(\(reaction.title))"
            )
        } catch {
            showIssueSavingPinAlert = true
        }
    }

    public func onUnpinReactionSelected(reaction: Reaction) async {
        do {
            try reactionRepository.removePin(reactionId: reaction.id)
            // I decided to reload the entire view because dealing with `position` proved convoluted.
            await loadReactions()

            await AnalyticsService().send(
                originatingScreen: "ReactionsView",
                action: "unpinnedReaction(\(reaction.title))"
            )
        } catch {
            showIssueRemovingPinAlert = true
        }
    }

    public func onUserTappedReactionInTrendsTab(
        _ reactionId: String,
        _ openAction: (Reaction) -> Void
    ) {
        guard case .loaded(let reactionGroup) = state else {
            reactionIdToOpenAfterLoading = reactionId
            return
        }
        guard let reaction = reactionGroup.regular.first(where: { $0.id == reactionId }) else {
            showIssueOpeningReaction = true
            return
        }
        openAction(reaction)
    }
}

// MARK: - Internal Functions

extension ReactionsView.ViewModel {

    private func loadReactions() async {
        state = .loading

        do {
            let serverReactions = try await reactionRepository.allReactions()
            let pinned = try await reactionRepository.pinnedReactions(serverReactions)

            let regular: [Reaction] = serverReactions.compactMap { serverReaction in
                guard !pinned.contains(where: { $0.id == serverReaction.id }) else { return nil }
                return serverReaction
            }

            state = .loaded(.init(pinned: pinned, regular: regular))

            checkIfNeedsToOpenReaction()
        } catch {
            state = .error(error.localizedDescription)

            await AnalyticsService().send(
                originatingScreen: "ReactionsView",
                action: "hadIssueLoadingReactions(\(error.localizedDescription))"
            )
        }
    }

    private func addToPinned(reaction: Reaction) {
        if case .loaded(let group) = state {
            var updatedGroup = group
            var updatedReaction = reaction
            updatedReaction.type = .pinnedExisting
            updatedGroup.pinned.append(updatedReaction)
            updatedGroup.regular.removeAll(where: { $0.id == reaction.id })
            state = .loaded(updatedGroup)
        }
    }

    private func donateActivity() {
        currentActivity = UserActivityWaiter.getDonatableActivity(
            withType: Shared.ActivityTypes.viewReactions,
            andTitle: "Ver Reações",
            persistentIdentifier: Shared.ActivityTypes.viewReactions
        )
        currentActivity?.becomeCurrent()
    }

    private func checkIfNeedsToOpenReaction() {
        if !reactionIdToOpenAfterLoading.isEmpty {
            if case .loaded(let group) = state {
                guard let reaction = group.regular.first(where: { $0.id == reactionIdToOpenAfterLoading }) else {
                    showIssueOpeningReaction = true
                    reactionIdToOpenAfterLoading = ""
                    return
                }
                reactionToOpen = reaction
            }
            reactionIdToOpenAfterLoading = ""
        }
    }
}
