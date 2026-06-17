//
//  AddToFolderView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI

struct AddToFolderView: View {

    @State private var viewModel = AddToFolderViewModel(
        userFolderRepository: UserFolderRepository(database: LocalDatabase.shared)
    )

    @Binding var details: AddToFolderDetails

    @State var selectedContent: [AnyEquatableMedoContent]
    @State private var newFolder: UserFolder?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    @Environment(\.dismiss) private var dismiss

    // MARK: - View Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: .spacing(.large)) {
                ScrollView {
                    VStack {
                        if viewModel.folders.count == 0 {
                            Text("Nenhuma Pasta")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(.vertical, 200)
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(viewModel.folders) { folder in
                                    Button {
                                        guard let result = viewModel.onExistingFolderSelected(
                                            folder: folder,
                                            selectedContent: selectedContent
                                        ) else { return }
                                        details = result
                                        dismiss()
                                    } label: {
                                        FolderView(folder: folder)
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Adicionar a uma Pasta")
            .navigationBarTitleDisplayMode(.inline)
            .padding(.horizontal)
            .onAppear {
                Task {
                    await viewModel.onViewAppeared()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newFolder = UserFolder.newFolder()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                switch viewModel.alertType {
                case .addOnlyNonOverlapping:
                    return Alert(
                        title: Text(viewModel.alertTitle),
                        message: Text(viewModel.alertMessage),
                        primaryButton: .default(Text("Adicionar"), action: {
                            guard let result = viewModel.onAddOnlyNonExistingSelected() else { return }
                            details = result
                            dismiss()
                        }),
                        secondaryButton: .cancel(Text("Cancelar"))
                    )

                default:
                    return Alert(
                        title: Text(viewModel.alertTitle),
                        message: Text(viewModel.alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .sheet(item: $newFolder) { folder in
                FolderInfoEditingView(
                    folder: folder,
                    folderRepository: UserFolderRepository(database: LocalDatabase.shared),
                    dismissSheet: {
                        newFolder = nil
                        Task {
                            await viewModel.onNewFolderCreationSheetDismissed()
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddToFolderView(
        details: .constant(AddToFolderDetails()),
        selectedContent: [
            AnyEquatableMedoContent(Sound(title: "ABCD", description: ""))
        ]
    )
}
