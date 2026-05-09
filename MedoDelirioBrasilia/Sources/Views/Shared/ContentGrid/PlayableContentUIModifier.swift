//
//  PlayableContentUIModifier.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 04/01/26.
//

import SwiftUI

/// A ViewModifier that attaches all shared alerts and sheets for playable content.
/// Use this on any view that displays content that can be played, favorited, shared, etc.
struct PlayableContentUIModifier: ViewModifier {

    @Bindable var state: PlayableContentState
    var toast: Binding<Toast?>
    var onAuthorSelected: ((Author) -> Void)?

    // Add to folder helper state
    @State private var addToFolderHelper = AddToFolderDetails()

    // For content detail navigation
    var authorId: String? = nil
    var reactionId: String? = nil
    var onReactionSelected: ((Reaction) -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(item: $state.alertState) { alertType in
                alertFor(alertType)
            }
            .sheet(item: $state.activeSheet) { sheet in
                sheetView(for: sheet)
            }
            .sheet(isPresented: $state.isShowingShareSheet) {
                if let shareSheet = state.iPadShareSheet {
                    shareSheet
                }
            }
            .onChange(of: state.shareAsVideoResult.videoFilepath) {
                state.onDidExitShareAsVideoSheet()
            }
            .onChange(of: state.authorToOpen) {
                guard let author = state.authorToOpen else { return }
                onAuthorSelected?(author)
                state.authorToOpen = nil
            }
            .onChange(of: state.activeSheet) {
                if state.activeSheet == nil && addToFolderHelper.hadSuccess {
                    Task {
                        await state.onAddedContentToFolderSuccessfully(
                            folderName: addToFolderHelper.folderName ?? "",
                            pluralization: addToFolderHelper.pluralization
                        )
                        addToFolderHelper = AddToFolderDetails()
                    }
                }
            }
    }

    // MARK: - Alert Builder

    private func alertFor(_ alertType: PlayableContentAlert) -> Alert {
        switch alertType {
        case .contentFileNotFound:
            return Alert(
                title: Text(state.alertTitle),
                message: Text(state.alertMessage),
                primaryButton: .default(
                    Text("Baixar Novamente"),
                    action: { state.onRedownloadContentOptionSelected() }
                ),
                secondaryButton: .cancel(Text("Cancelar"))
            )

        case .issueSharingContent:
            return Alert(
                title: Text(state.alertTitle),
                message: Text(state.alertMessage),
                primaryButton: .default(
                    Text("Relatar Problema por E-mail"),
                    action: { Task { await state.onReportContentIssueSelected() } }
                ),
                secondaryButton: .cancel(Text("Cancelar"))
            )

        case .unableToRedownloadContent:
            return Alert(
                title: Text(state.alertTitle),
                message: Text(state.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Sheet Builder

    @ViewBuilder
    private func sheetView(for sheet: PlayableContentSheet) -> some View {
        switch sheet {
        case .shareAsVideo(let content):
            ShareAsVideoView(
                viewModel: ShareAsVideoViewModel(
                    content: content,
                    subtitle: content.subtitle,
                    contentType: state.typeForShareAsVideo(),
                    result: Binding(
                        get: { state.shareAsVideoResult },
                        set: { state.shareAsVideoResult = $0 }
                    )
                ),
                useLongerGeneratingVideoMessage: content.type == .song
            )

        case .addToFolder(let contents):
            AddToFolderView(
                details: $addToFolderHelper,
                selectedContent: contents
            )
            .presentationDetents([.medium, .large])

        case .contentDetail(let content):
            ContentDetailView(
                content: content,
                openAuthorDetailsAction: { author in
                    guard author.id != self.authorId else { return }
                    state.activeSheet = nil
                    onAuthorSelected?(author)
                },
                authorId: authorId,
                openReactionAction: { reaction in
                    state.activeSheet = nil
                    onReactionSelected?(reaction)
                },
                reactionId: reactionId,
                dismissAction: { state.activeSheet = nil }
            )
        }
    }
}

// MARK: - View Extension

extension View {

    /// Attaches playable content UI (alerts, sheets) to this view.
    /// - Parameters:
    ///   - state: The PlayableContentState to bind to
    ///   - toast: Binding to display toast messages
    ///   - authorId: Optional author ID for content detail navigation
    ///   - reactionId: Optional reaction ID for content detail navigation
    ///   - onAuthorSelected: Callback when an author is selected
    ///   - onReactionSelected: Callback when a reaction is selected
    func playableContentUI(
        state: PlayableContentState,
        toast: Binding<Toast?>,
        authorId: String? = nil,
        reactionId: String? = nil,
        onAuthorSelected: ((Author) -> Void)? = nil,
        onReactionSelected: ((Reaction) -> Void)? = nil
    ) -> some View {
        modifier(PlayableContentUIModifier(
            state: state,
            toast: toast,
            onAuthorSelected: onAuthorSelected,
            authorId: authorId,
            reactionId: reactionId,
            onReactionSelected: onReactionSelected
        ))
    }
}

