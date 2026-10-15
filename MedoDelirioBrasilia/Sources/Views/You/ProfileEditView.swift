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

    /// The favorites, curated on the server, in their order. Shown in their own row
    /// before everyone, for quick access.
    private var featuredAuthors: [Author] {
        authors
            .filter { $0.featuredRank != nil }
            .sorted { lhs, rhs in
                lhs.featuredRank != rhs.featuredRank
                    ? (lhs.featuredRank ?? .max) < (rhs.featuredRank ?? .max)
                    : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private var selectedPhoto: String? {
        authors.first { $0.id == selectedAuthorID }?.photo
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing(.large)) {
                    ProfileAvatarView(photo: selectedPhoto, size: 120)
                        .padding(.top, .spacing(.medium))

                    NicknameField(nickname: $nickname, limit: Self.nicknameLimit)

                    if !featuredAuthors.isEmpty {
                        featuredRow
                    }

                    VStack(alignment: .leading, spacing: .spacing(.small)) {
                        Text(featuredAuthors.isEmpty ? "Foto" : "Todos")
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
                        save()
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

// MARK: - Featured Row

extension ProfileEditView {

    /// Sideways, edge to edge, so it reads as a shelf apart from the grid below.
    private var featuredRow: some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text("Destaques")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: .spacing(.medium)) {
                    ForEach(featuredAuthors) { author in
                        AvatarChoice(
                            photo: author.photo,
                            name: author.name,
                            isSelected: selectedAuthorID == author.id
                        ) {
                            selectedAuthorID = author.id
                        }
                        .frame(width: 80)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, .spacing(.medium), for: .scrollContent)
            // Out to the screen's edges, past the page's own padding.
            .padding(.horizontal, -.spacing(.medium))
        }
    }
}

// MARK: - Nickname Field

extension ProfileEditView {

    /// The nickname, set apart from the photo grid: a title, a tall field that outlines in
    /// the accent color while typing, a clear button, and a line saying where the
    /// nickname shows, with a character count.
    struct NicknameField: View {

        @Binding var nickname: String
        let limit: Int

        @FocusState private var isFocused: Bool

        private static let cornerRadius: CGFloat = 16

        var body: some View {
            VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                Text("Apelido")
                    .font(.headline)

                HStack(spacing: .spacing(.small)) {
                    TextField("Como você quer aparecer", text: $nickname)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isFocused)

                    if !nickname.isEmpty {
                        Button {
                            nickname = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Apagar apelido")
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, .spacing(.medium))
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .strokeBorder(
                            isFocused ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.separator),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
                .onTapGesture {
                    isFocused = true
                }
                .animation(.snappy(duration: 0.2), value: isFocused)
                .animation(.snappy(duration: 0.2), value: nickname.isEmpty)

                HStack(alignment: .firstTextBaseline) {
                    Text("Aparece no topo do Você e nas imagens que você compartilhar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: .spacing(.small))

                    Text("\(nickname.count)/\(limit)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(nickname.count) de \(limit) caracteres")
                }
            }
            .onChange(of: nickname) {
                if nickname.count > limit {
                    nickname = String(nickname.prefix(limit))
                }
            }
        }
    }
}

// MARK: - Saving

extension ProfileEditView {

    /// Saves, and reports what changed, so it shows whether people take to having a
    /// profile at all. Nothing is reported when nothing changed.
    private func save() {
        let avatarChanged = selectedAuthorID != profileStore.avatarAuthorID
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let nicknameChanged = (trimmed.isEmpty ? nil : trimmed) != profileStore.nickname

        profileStore.update(avatarAuthorID: selectedAuthorID, nickname: nickname)

        guard avatarChanged || nicknameChanged else { return }
        // Whose photo it is, by name, to see which faces people pick. "nenhuma" for
        // "Sem foto".
        let avatar = authors.first { $0.id == selectedAuthorID }?.name ?? "nenhuma"
        let action = "didEditProfile(avatarChanged: \(avatarChanged), nicknameChanged: \(nicknameChanged), "
            + "avatar: \(avatar), hasNickname: \(profileStore.nickname != nil))"
        Task {
            await AnalyticsService().send(originatingScreen: "ProfileEditView", action: action)
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
