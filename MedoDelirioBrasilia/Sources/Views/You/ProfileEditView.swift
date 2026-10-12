//
//  ProfileEditView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// Picks the avatar from the podcast's cast and sets the nickname.
struct ProfileEditView: View {

    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String = ""
    @State private var selectedAuthorID: String?
    @State private var authors: [Author] = []

    private static let nicknameLimit = 30

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: .spacing(.medium))]

    private var selectedPhoto: String? {
        authors.first { $0.id == selectedAuthorID }?.photo
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing(.large)) {
                    ProfileAvatarView(photo: selectedPhoto, size: 120)
                        .padding(.top, .spacing(.medium))

                    TextField("Apelido", text: $nickname)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onChange(of: nickname) {
                            if nickname.count > Self.nicknameLimit {
                                nickname = String(nickname.prefix(Self.nicknameLimit))
                            }
                        }

                    VStack(alignment: .leading, spacing: .spacing(.small)) {
                        Text("Foto")
                            .font(.headline)

                        LazyVGrid(columns: columns, spacing: .spacing(.medium)) {
                            AvatarChoice(
                                photo: nil,
                                name: "Sem foto",
                                isSelected: selectedAuthorID == nil
                            ) {
                                selectedAuthorID = nil
                            }

                            ForEach(authors) { author in
                                AvatarChoice(
                                    photo: author.photo,
                                    name: author.name,
                                    isSelected: selectedAuthorID == author.id
                                ) {
                                    selectedAuthorID = author.id
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, .spacing(.large))
            }
            .navigationTitle("Seu perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        profileStore.update(avatarAuthorID: selectedAuthorID, nickname: nickname)
                        dismiss()
                    }
                }
            }
            .onAppear {
                nickname = profileStore.nickname ?? ""
                selectedAuthorID = profileStore.avatarAuthorID
                authors = ((try? LocalDatabase.shared.allAuthors()) ?? [])
                    .filter { $0.photo?.isEmpty == false }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        }
    }
}

// MARK: - Avatar Choice

extension ProfileEditView {

    struct AvatarChoice: View {

        let photo: String?
        let name: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: .spacing(.xxSmall)) {
                    ProfileAvatarView(photo: photo, size: 64)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                        }

                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

#Preview {
    ProfileEditView()
        .environment(ProfileStore(cloudStore: FakeCloudKeyValueStore(), database: FakeLocalDatabase()))
}
