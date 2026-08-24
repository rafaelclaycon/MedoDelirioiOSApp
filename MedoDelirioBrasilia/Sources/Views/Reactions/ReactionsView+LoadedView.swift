//
//  ReactionsView+LoadedView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 10/11/24.
//

import LinkPresentation
import SwiftUI

extension ReactionsView {

    struct LoadedView: View {

        let pinnedReactions: [Reaction]?
        let otherReactions: [Reaction]
        let columns: [GridItem]
        let pinAction: (Reaction) -> Void
        let unpinAction: (Reaction) -> Void
        let goToFolders: () -> Void

        @State private var removedReaction: Reaction?
        @State private var showReactionRemovedAlert = false
        @State private var shouldDisplayPinBanner: Bool = false
        @State private var shouldDisplayFoldersPromoBanner: Bool = false

        @State private var isPreparingShare: Bool = false
        @State private var shareLinkMetadata: LPLinkMetadata?

        var body: some View {
            VStack {
                if shouldDisplayFoldersPromoBanner {
                    FoldersPromoBanner(
                        isBeingShown: $shouldDisplayFoldersPromoBanner,
                        goToFolders: goToFolders
                    )
                    .layoutPriority(1)
                    .padding(.bottom)
                }

                // Commented out, not removed: crowded the top of this screen
                // alongside the folders promo banner. Bring back if the folders
                // banner becomes permanent-dismiss-only instead of one-time.
//                if shouldDisplayPinBanner {
//                    PinReactionsBanner(
//                        isBeingShown: $shouldDisplayPinBanner
//                    )
//                    .layoutPriority(1)
//                    .padding(.bottom)
//                }

                if let pinnedReactions, pinnedReactions.count > 0 {
                    LazyVGrid(
                        columns: columns,
                        spacing: UIDevice.deviceType == .iPhone ? 12 : 20
                    ) {
                        ForEach(pinnedReactions) { reaction in
                            InteractibleReactionItem(
                                reaction: reaction,
                                isPinned: true,
                                options: {
                                    Button {
                                        unpinAction(reaction)
                                    } label: {
                                        Label("Desafixar", systemImage: "pin.slash")
                                    }
                                },
                                reactionRemovedAction: {
                                    print("Reaction removed: \($0.title)")
                                    removedReaction = $0
                                    showReactionRemovedAlert = true
                                }
                            )
                        }
                    }

                    Divider()
                        .padding(.vertical, 10)
                }

                LazyVGrid(
                    columns: columns,
                    spacing: UIDevice.deviceType == .iPhone ? 12 : 20
                ) {
                    ForEach(otherReactions) { reaction in
                        InteractibleReactionItem(
                            reaction: reaction,
                            isPinned: false,
                            options: {
                                Button {
                                    pinAction(reaction)
                                } label: {
                                    Label("Fixar no Topo", systemImage: "pin")
                                }
                                Button { shareAction(reaction) } label: {
                                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                                }
                            },
                            reactionRemovedAction: { _ in }
                        )
                    }
                }
            }
            .padding()
            .onAppear {
                shouldDisplayPinBanner = !AppPersistentMemory.shared.hasSeenPinReactionsBanner()
                shouldDisplayFoldersPromoBanner = !AppPersistentMemory.shared.hasSeenFoldersPromoBanner()
            }
            .sheet(item: $shareLinkMetadata) { metadata in
                LinkMetadataShareSheet(metadata: metadata)
                    .presentationDetents([.medium, .large])
            }
            .alert(
                "A Reação \"\(removedReaction?.title ?? "")\" Foi Removida",
                isPresented: $showReactionRemovedAlert,
                actions: {
                    Button("Remover Fixação", action: {
                        guard let reaction = removedReaction else { return }
                        unpinAction(reaction)
                    })
                },
                message: { Text("Essa reação foi removida do servidor durante uma revisão. Pedimos desculpas pelo inconveniente.") }
            )
        }

        // MARK: - Share

        func shareAction(_ reaction: Reaction) {
            guard !isPreparingShare else { return }
            guard let shareURL = URL(string: APIConfig.baseLinkURL + "reacao/\(reaction.id)") else { return }
            isPreparingShare = true

            Task {
                let meta = LPLinkMetadata()
                meta.url = shareURL
                meta.title = "Reação \(reaction.title.capitalized(with: Locale(identifier: "pt_BR")))"

                if let imageURL = URL(string: reaction.image),
                   let (data, _) = try? await URLSession.shared.data(from: imageURL),
                   let image = UIImage(data: data) {
                    meta.imageProvider = NSItemProvider(object: image)
                }

                shareLinkMetadata = meta
                isPreparingShare = false
            }
        }
    }

    struct InteractibleReactionItem<Options: View>: View {

        let reaction: Reaction
        let isPinned: Bool
        let options: Options
        let reactionRemovedAction: (Reaction) -> Void

        init(
            reaction: Reaction,
            isPinned: Bool,
            @ViewBuilder options: () -> Options,
            reactionRemovedAction: @escaping (Reaction) -> Void
        ) {
            self.reaction = reaction
            self.isPinned = isPinned
            self.options = options()
            self.reactionRemovedAction = reactionRemovedAction
        }

        @Environment(\.push) var push

        var body: some View {
            ReactionItem(reaction: reaction)
                .onTapGesture {
                    if reaction.type == .pinnedRemoved {
                        reactionRemovedAction(reaction)
                    } else {
                        push(GeneralNavigationDestination.reactionDetail(reaction))
                    }
                }
                .contextMenu {
                    options
                }
                .contentShape(
                    .contextMenuPreview,
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }
}

// MARK: - Preview

#Preview("Pinned Reaction") {
    ReactionsView.InteractibleReactionItem(
        reaction: Reaction.enthusiasmMock,
        isPinned: true,
        options: {
            Button {
                print("Tapped")
            } label: {
                Label("Desafixar", systemImage: "pin.slash")
            }
        },
        reactionRemovedAction: { _ in }
    )
    .padding()
}
