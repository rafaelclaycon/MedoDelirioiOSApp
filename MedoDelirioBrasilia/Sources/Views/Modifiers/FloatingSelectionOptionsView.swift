//
//  FloatingSelectionOptionsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 29/09/23.
//

import SwiftUI

public struct FloatingContentOptions {

    public var areButtonsEnabled: Bool
    public var allSelectedAreFavorites: Bool
    public let folderOperation: FolderOperation
    public var shareIsProcessing: Bool

    public let favoriteAction: () -> Void
    public let folderAction: () -> Void
    public let shareAction: () -> Void

    public init(
        areButtonsEnabled: Bool,
        allSelectedAreFavorites: Bool,
        folderOperation: FolderOperation,
        shareIsProcessing: Bool,
        favoriteAction: @escaping () -> Void,
        folderAction: @escaping () -> Void,
        shareAction: @escaping () -> Void
    ) {
        self.areButtonsEnabled = areButtonsEnabled
        self.allSelectedAreFavorites = allSelectedAreFavorites
        self.folderOperation = folderOperation
        self.shareIsProcessing = shareIsProcessing
        self.favoriteAction = favoriteAction
        self.folderAction = folderAction
        self.shareAction = shareAction
    }
}

struct FloatingSelectionOptionsView: ViewModifier {

    // MARK: - Dependencies

    @Binding private var options: FloatingContentOptions?

    public init(_ options: Binding<FloatingContentOptions?>) {
        _options = options
    }

    // MARK: - Computed Properties

    private var favoriteSymbol: String {
        guard let options else { return "" }
        return options.allSelectedAreFavorites ? "heart.slash" : "heart"
    }

    private var favoriteTitle: String {
        guard let options else { return "" }
        if options.allSelectedAreFavorites {
            return UIDevice.deviceType == .iPhone ? "Desfav." : "Desfavoritar"
        } else {
            return "Favoritar"
        }
    }

    private var folderSymbol: String {
        guard let options else { return "" }
        return options.folderOperation == .add ? "folder.badge.plus" : "folder.badge.minus"
    }

    private var folderTitle: String {
        if UIDevice.deviceType == .iPhone {
            return "Pasta"
        } else {
            guard let options else { return "" }
            return options.folderOperation == .add ? "Adicionar a Pasta" : "Remover da Pasta"
        }
    }

    // MARK: - Body

    public func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .toolbar {
                    if let options {
                        ToolbarItem(placement: .bottomBar) {
                            Button {
                                options.favoriteAction()
                            } label: {
                                Label {
                                    Text(favoriteTitle).bold()
                                } icon: {
                                    Image(systemName: favoriteSymbol)
                                }
                            }
                            .disabled(!options.areButtonsEnabled)
                        }

                        ToolbarItem(placement: .bottomBar) {
                            Button {
                                options.folderAction()
                            } label: {
                                Label {
                                    Text(folderTitle)
                                        .bold()
                                } icon: {
                                    Image(systemName: folderSymbol)
                                }
                            }
                            .disabled(!options.areButtonsEnabled)
                        }

                        ToolbarSpacer(.flexible, placement: .bottomBar)

                        ToolbarItem(placement: .bottomBar) {
                            if options.shareIsProcessing {
                                ProgressView()
                            } else {
                                Button {
                                    options.shareAction()
                                } label: {
                                    Label {
                                        Text(UIDevice.deviceType == .iPhone ? "Comp." : "Compartilhar")
                                            .bold()
                                    } icon: {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                }
                                .disabled(!options.areButtonsEnabled || UIDevice.deviceType != .iPhone) // Sharing many crashed on iPad.
                            }
                        }
                    }
                }
        } else {
            content
                .overlay(alignment: .bottom) {
                    if let options {
                        HStack(spacing: 14) {
                            Button {
                                options.favoriteAction()
                            } label: {
                                Label {
                                    Text(favoriteTitle).bold()
                                } icon: {
                                    Image(systemName: favoriteSymbol)
                                }
                            }
                            .disabled(!options.areButtonsEnabled)

                            Divider()

                            Button {
                                options.folderAction()
                            } label: {
                                Label {
                                    Text(folderTitle)
                                        .bold()
                                } icon: {
                                    Image(systemName: folderSymbol)
                                }
                            }
                            .disabled(!options.areButtonsEnabled)

                            Divider()

                            if options.shareIsProcessing {
                                ProgressView()
                                    .frame(width: 80)
                            } else {
                                Button {
                                    options.shareAction()
                                } label: {
                                    Label {
                                        Text(UIDevice.deviceType == .iPhone ? "Comp." : "Compartilhar")
                                            .bold()
                                    } icon: {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                }
                                .disabled(!options.areButtonsEnabled || UIDevice.deviceType != .iPhone) // Sharing many crashed on iPad.
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(maxHeight: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 50, style: .continuous)
                                .fill(Color.systemBackground)
                                .shadow(color: .gray, radius: 2, y: 2)
                        }
                        .padding(.bottom)
                        .disabled(options.shareIsProcessing)
                    }
                }
        }
    }
}

// MARK: - Modifiers

public extension View {

    /// Adds a `FloatingSelectionOptionsView` to the view's safe area inset.
    /// - Parameters:
    ///   - options: Binding to options to display. When nil, options are not presented.
    func floatingContentOptions(_ options: Binding<FloatingContentOptions?>) -> some View {
        modifier(FloatingSelectionOptionsView(options))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Rectangle()
            .fill(Color.brightGreen)
            .floatingContentOptions(
                .constant(FloatingContentOptions(
                    areButtonsEnabled: true,
                    allSelectedAreFavorites: false,
                    folderOperation: .add,
                    shareIsProcessing: false,
                    favoriteAction: { },
                    folderAction: { },
                    shareAction: { }
                ))
            )
    }
}
