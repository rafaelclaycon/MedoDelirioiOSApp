//
//  FolderInfoEditingView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI
import Combine

struct FolderInfoEditingView: View {

    @State private var viewModel: ViewModel

    @FocusState private var focusedField: Field?

    private let dismissSheet: () -> Void

    // MARK: - Initializer

    init(
        folder: UserFolder,
        folderRepository: UserFolderRepositoryProtocol,
        dismissSheet: @escaping () -> Void
    ) {
        self.viewModel = ViewModel(
            folder: folder,
            folderRepository: folderRepository,
            dismissSheet: dismissSheet
        )
        self.dismissSheet = dismissSheet
    }

    // MARK: - View Body

    var body: some View {
        NavigationStack {
            ScrollView {
                // Trimmed from .medium, and the old top/bottom Spacer()s dropped:
                // both were fine at rest, but with the emoji keyboard up, iOS
                // auto-scrolls to keep the focused EmojiField visible — pushing
                // everything below it, including NameField, further down. Every
                // point saved here is a point more likely to keep NameField reachable.
                VStack(spacing: .spacing(.small)) {
                    EmojiField(
                        symbol: $viewModel.folder.symbol,
                        backgroundColor: viewModel.folder.backgroundColor.toPastelColor()
                    )
                    .focused($focusedField, equals: .symbol)

                    Text("1. Digite um emoji no espaço acima para representar a pasta.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .onTapGesture {
                            focusedField = nil
                        }

                    if ProcessInfo.processInfo.isMacCatalystApp {
                        Text("Para acessar os emojis no Mac, pressione Control + Command + Espaço.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    NameField(name: $viewModel.folder.name)
                        .focused($focusedField, equals: .folderName)
                }
                .padding(.vertical, .spacing(.medium))
                .padding(.horizontal, .spacing(.medium))
                .navigationTitle(viewModel.isEditing ? "Editar Pasta" : "Nova Pasta")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        CloseButton {
                            dismissSheet()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        if #available(iOS 26, *) {
                            Button {
                                viewModel.onSaveSelected()
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.accentColor)
                            .disabled(viewModel.saveCreateButtonIsDisabled)
                        } else {
                            Button {
                                viewModel.onSaveSelected()
                            } label: {
                                Text(viewModel.isEditing ? "Salvar" : "Criar")
                                    .bold()
                            }
                            .disabled(viewModel.saveCreateButtonIsDisabled)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                    Text("3. ESCOLHA UMA COR:")
                        .font(.callout)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .padding(.leading)

                    ColorPicker(
                        selectedBackgroundColor: viewModel.folder.backgroundColor,
                        colorSelectionAction: { viewModel.onPickedColorChanged($0) }
                    )
                }
                .padding(.top, .spacing(.xSmall))
                .background(Color.systemBackground)
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(600)) {
                    if viewModel.isEditing {
                        focusedField = .folderName
                    } else {
                        focusedField = .symbol
                    }
                }
            }
        }
    }
}

// MARK: - Field

extension FolderInfoEditingView {

    internal enum Field: Int, Hashable {
        case symbol, folderName
    }
}

// MARK: - Subviews

extension FolderInfoEditingView {

    struct EmojiField: View {

        @Binding var symbol: String
        let backgroundColor: Color

        /// Smaller than the grid card's own 0.85: this icon is decorative while the
        /// user is looking at the emoji keyboard, not at it, and every point saved
        /// here helps keep NameField reachable once the keyboard is up.
        private let scale: CGFloat = 0.9

        var body: some View {
            FolderView.FolderIcon(
                color: backgroundColor,
                emoji: "",
                isEmpty: true,
                scale: scale
            )
            .frame(width: 180 * scale)
            // Matches where FolderIcon centers its own emoji at this scale: within
            // the flap specifically, not the icon's full height — the flap is a
            // `.frame(height: 110 * scale)` bottom overlay offset down by `3 * scale`,
            // not the vertical center of the whole (taller, tab-included) icon.
            .overlay(alignment: .bottom) {
                TextField("", text: $symbol)
                    .font(.system(size: 44 * scale))
                    .multilineTextAlignment(.center)
                    .frame(height: 110 * scale)
                    .offset(y: 3 * scale)
                    .onReceive(Just(symbol)) { _ in
                        limitSymbolText(1)
                    }
            }
        }

        private func limitSymbolText(_ upper: Int) {
            if symbol.count > upper {
                symbol = String(symbol.prefix(upper))
            }
        }
    }

    struct NameField: View {

        @Binding var name: String

        var body: some View {
            VStack {
                TextField("2. Nome da pasta", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onReceive(Just(name)) { _ in
                        limitFolderNameText(25)
                    }


                HStack {
                    Spacer()

                    Text("\(name.count)/25")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
        }

        private func limitFolderNameText(_ upper: Int) {
            if name.count > upper {
                name = String(name.prefix(upper))
            }
        }
    }

    struct ColorPicker: View {

        let selectedBackgroundColor: String
        let colorSelectionAction: (String) -> Void

        var body: some View {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 5) {
                    ForEach(FolderColorFactory.getColors()) { folderColor in
                        ColorSelectionCell(
                            color: folderColor.color,
                            isSelected: folderColor.id == selectedBackgroundColor,
                            colorSelectionAction: colorSelectionAction
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, .spacing(.xSmall))
            }
        }
    }
}

// MARK: - Preview

#Preview("New Folder") {
    FolderInfoEditingView(
        folder: UserFolder.newFolder(),
        folderRepository: UserFolderRepository(database: FakeLocalDatabase()),
        dismissSheet: {}
    )
}
