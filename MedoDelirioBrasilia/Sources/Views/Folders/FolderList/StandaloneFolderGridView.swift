//
//  StandaloneFolderGridView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 19/07/22.
//

import SwiftUI

/// iPad and Mac only.
struct StandaloneFolderGridView: View {

    @Binding var folderForEditing: UserFolder?
    @Binding var updateFolderList: Bool
    let contentRepository: ContentRepositoryProtocol

    @State private var folderIdForEditing: String = ""
    @State private var showErrorDeletingAlert: Bool = false

    @State private var deleteFolderAide = DeleteFolderViewAide()

    // MARK: - View Body

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .center) {
                    FolderGrid(
                        viewModel: FolderGridViewModel(
                            userFolderRepository: UserFolderRepository(database: LocalDatabase.shared),
                            userSettings: UserSettings(),
                            appMemory: AppPersistentMemory.shared
                        ),
                        updateFolderList: $updateFolderList,
                        folderForEditing: $folderForEditing,
                        contentRepository: contentRepository,
                        containerSize: geometry.size
                    )
                    .environment(deleteFolderAide)
                }
                .padding(.horizontal, .spacing(.medium))
                .padding(.top, 7)
                .padding(.bottom, 18)
                .frame(minHeight: geometry.size.height)
            }
            .navigationTitle("Pastas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 20) {
                        Button {
                            folderForEditing = UserFolder.newFolder()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .alert(isPresented: $deleteFolderAide.showAlert) {
                Alert(
                    title: Text(deleteFolderAide.alertTitle),
                    message: Text(deleteFolderAide.alertMessage),
                    primaryButton: .destructive(
                        Text("Apagar"),
                        action: {
                            guard !deleteFolderAide.folderIdForDeletion.isEmpty else {
                                return
                            }

                            do {
                                try LocalDatabase.shared.deleteUserFolder(withId: deleteFolderAide.folderIdForDeletion)
                                updateFolderList = true
                            } catch {
                                showErrorDeletingAlert = true
                            }

                        }
                    ),
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
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StandaloneFolderGridView(
            folderForEditing: .constant(nil),
            updateFolderList: .constant(false),
            contentRepository: FakeContentRepository()
        )
    }
}
