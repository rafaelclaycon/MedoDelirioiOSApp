//
//  MyFoldersiPhoneView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 04/11/22.
//

import SwiftUI

struct MyFoldersiPhoneView: View {

    let contentRepository: ContentRepositoryProtocol
    let userFolderRepository: UserFolderRepositoryProtocol
    let containerSize: CGSize

    @State private var folderForEditing: UserFolder?
    @State private var updateFolderList: Bool = false // Does nothing, just here to satisfy FolderGrid :)
    @State private var currentContentListMode: ContentGridMode = .regular
    @State private var displayDeleteFolderAlert: Bool = false
    @State private var showErrorDeletingAlert: Bool = false

    @Environment(DeleteFolderViewAide.self) private var deleteFolderAide

    // MARK: - View Body

    var body: some View {
        VStack(alignment: .center) {
            FolderGrid(
                viewModel: FolderGridViewModel(
                    userFolderRepository: userFolderRepository,
                    userSettings: UserSettings(),
                    appMemory: AppPersistentMemory.shared
                ),
                updateFolderList: $updateFolderList,
                folderForEditing: $folderForEditing,
                contentRepository: contentRepository,
                containerSize: containerSize
            )
        }
        .padding(.top, 7)
        .padding(.bottom, 18)
        .navigationTitle("Minhas Pastas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    folderForEditing = UserFolder.newFolder()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $folderForEditing) { folder in
            FolderInfoEditingView(
                folder: folder,
                folderRepository: userFolderRepository,
                dismissSheet: {
                    folderForEditing = nil
                    updateFolderList = true
                }
            )
        }
        .onChange(of: deleteFolderAide.showAlert) {
            if deleteFolderAide.showAlert {
                displayDeleteFolderAlert = true
                deleteFolderAide.showAlert = false
            }
        }
        .alert(isPresented: $displayDeleteFolderAlert) {
            Alert(
                title: Text(deleteFolderAide.alertTitle),
                message: Text(deleteFolderAide.alertMessage),
                primaryButton: .destructive(Text("Apagar"), action: deleteFolder),
                secondaryButton: .cancel(Text("Cancelar"))
            )
        }
        .alert(
            "Erro Ao Tentar Apagar a Pasta",
            isPresented: $showErrorDeletingAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Tente novamente mais tarde. Se o erro persisir, por favor, envie um e-mail para o desenvolvedor.")
        }
    }

    // MARK: - Functions

    private func deleteFolder() {
        guard !deleteFolderAide.folderIdForDeletion.isEmpty else {
            return
        }
        do {
            try userFolderRepository.delete(deleteFolderAide.folderIdForDeletion)
            updateFolderList = true
        } catch {
            showErrorDeletingAlert = true
        }
    }
}

// MARK: - Preview

#Preview {
    MyFoldersiPhoneView(
        contentRepository: FakeContentRepository(),
        userFolderRepository: UserFolderRepository(database: FakeLocalDatabase()),
        containerSize: CGSize(width: 400, height: 1200)
    )
}
