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
                VStack(spacing: .spacing(.medium)) {
                    Spacer()

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

                    Spacer()
                }
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

        var body: some View {
            FolderView.FolderIcon(
                color: backgroundColor,
                emoji: "",
                isEmpty: true
            )
            .frame(width: 180)
            .overlay {
                HStack {
                    Spacer()

                    TextField("", text: $symbol)
                        .font(.system(size: 44))
                        .padding(.leading, .spacing(.medium))
                        .multilineTextAlignment(.leading)
                        .onReceive(Just(symbol)) { _ in
                            limitSymbolText(1)
                        }

                    Spacer()
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
