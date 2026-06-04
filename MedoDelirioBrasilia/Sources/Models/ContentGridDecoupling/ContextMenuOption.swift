//
//  ContextMenuOption.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import UIKit

struct ContextMenuPassthroughData {

    let selectedContent: AnyEquatableMedoContent
    let loadedContent: [AnyEquatableMedoContent]
    let isFavoritesOnlyView: Bool
}

struct ContextMenuOption: Identifiable {

    let id: UUID = UUID()
    let symbol: (Bool) -> String
    let title: (Bool) -> String
    let appliesTo: [MediaType]
    let action: (ContentGridDisplaying, ContextMenuPassthroughData) -> Void
}

struct ContextMenuSection {

    let title: String
    let options: (AnyEquatableMedoContent) -> [ContextMenuOption]
}

extension ContextMenuOption {

    static var shareContent: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "square.and.arrow.up" },
            title: { _ in Shared.shareSoundButtonText },
            appliesTo: [.sound, .song]
        ) { delegate, data in
            delegate.share(content: data.selectedContent)
        }
    }

    static var shareAsVideo: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "film"},
            title: { _ in Shared.shareAsVideoButtonText },
            appliesTo: [.sound, .song]
        ) { delegate, data in
            delegate.openShareAsVideoModal(for: data.selectedContent)
        }
    }

    static var addToFavorites: ContextMenuOption {
        return ContextMenuOption(
            symbol: { isFavorite in
                isFavorite ? "heart.slash" : "heart"
            },
            title: { isFavorite in
                isFavorite ? Shared.removeFromFavorites : Shared.addToFavorites
            },
            appliesTo: [.sound, .song]
        ) { delegate, data in
            delegate.toggleFavorite(data.selectedContent.id, isFavoritesOnlyView: data.isFavoritesOnlyView)
        }
    }

    static var addToFolder: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "folder.badge.plus" },
            title: { _ in Shared.addToFolderButtonText },
            appliesTo: [.sound, .song]
        ) { delegate, data in
            delegate.addToFolder(data.selectedContent)
        }
    }

    static var viewAuthor: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "person" },
            title: { _ in "Ver Autor" },
            appliesTo: [.sound]
        ) { delegate, data in
            guard !data.selectedContent.authorId.isEmpty else { return }
            delegate.showAuthor(withId: data.selectedContent.authorId)
        }
    }

    static var viewMusicGenre: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "guitars" },
            title: { _ in "Ver Gênero Musical" },
            appliesTo: [.song]
        ) { delegate, data in
            print("Not implemented yet!")
        }
    }

    static var viewDetails: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "info.circle" },
            title: { _ in "Ver Detalhes" },
            appliesTo: [.sound, .song]
        ) { delegate, data in
            delegate.showDetails(for: data.selectedContent)
        }
    }
}

// MARK: - Folder Options

extension ContextMenuOption {

    static var playFromThisSound: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "play"},
            title: { _ in "Tocar a Partir Desse"},
            appliesTo: [.sound, .song]
        ) { delegate, data in
            delegate.playFrom(content: data.selectedContent, loadedContent: data.loadedContent)
        }
    }

    static var removeContentFromFolder: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "folder.badge.minus"},
            title: { _ in "Remover da Pasta"},
            appliesTo: [.sound, .song]
        ) { delegate, data in
            delegate.removeFromFolder(data.selectedContent)
        }
    }
}

// MARK: - Author Options

extension ContextMenuOption {

    static var suggestOtherAuthorName: ContextMenuOption {
        ContextMenuOption(
            symbol: { _ in "exclamationmark.bubble"},
            title: { _ in "Sugerir Outro Nome de Autor"},
            appliesTo: [.sound]
        ) { delegate, data in
            Task {
                await delegate.suggestOtherAuthorName(for: data.selectedContent)
            }
        }
    }
}

extension ContextMenuSection {

    static func sharingOptions() -> ContextMenuSection {
        return ContextMenuSection(
            title: "Sharing",
            options: { _ in
                [
                    .shareContent,
                    .shareAsVideo
                ]
            }
        )
    }

    static func organizingOptions() -> ContextMenuSection {
        return ContextMenuSection(
            title: "Organizing",
            options: { _ in
                [
                    ContextMenuOption.addToFavorites,
                    ContextMenuOption.addToFolder
                ]
            }
        )
    }

    static func detailsOptions() -> ContextMenuSection {
        return ContextMenuSection(
            title: "Details",
            options: { _ in
                [
                    ContextMenuOption.viewAuthor,
                    //ContextMenuOption.viewMusicGenre,
                    ContextMenuOption.viewDetails
                ]
            }
        )
    }

    static func playFromThisSound() -> ContextMenuSection {
        return ContextMenuSection(
            title: "PlayFromThis",
            options: { _ in
                [
                    ContextMenuOption.playFromThisSound
                ]
            }
        )
    }

    static func removeFromFolder() -> ContextMenuSection {
        return ContextMenuSection(
            title: "RemoveFromFolder",
            options: { _ in
                [
                    ContextMenuOption.removeContentFromFolder
                ]
            }
        )
    }

    static func authorOptions() -> ContextMenuSection {
        return ContextMenuSection(
            title: "AuthorOptions",
            options: { _ in
                [
                    ContextMenuOption.suggestOtherAuthorName,
                    ContextMenuOption.viewDetails
                ]
            }
        )
    }
}
