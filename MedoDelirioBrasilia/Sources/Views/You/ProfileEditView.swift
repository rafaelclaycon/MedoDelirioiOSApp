//
//  ProfileEditView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import PhotosUI
import SwiftUI

/// Picks the avatar, the user's own photo or one from the podcast's cast, and sets the
/// nickname.
struct ProfileEditView: View {

    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String = ""
    @State private var selectedAuthorID: String?
    @State private var authors: [Author] = []
    /// Kept while browsing the cast, so picking an author and coming back to "Sua foto"
    /// doesn't mean choosing the photo again.
    @State private var customPhoto: Data?
    @State private var usesCustomPhoto = false
    @State private var isShowingPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var photoToCrop: PhotoToCrop?

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
                    ProfileAvatarView(
                        photo: usesCustomPhoto ? nil : selectedPhoto,
                        customPhoto: usesCustomPhoto ? customPhoto : nil,
                        size: 120
                    )
                        .padding(.top, .spacing(.medium))

                    NicknameField(nickname: $nickname, limit: Self.nicknameLimit)

                    if !featuredAuthors.isEmpty {
                        featuredRow
                    }

                    VStack(alignment: .leading, spacing: .spacing(.small)) {
                        Text(featuredAuthors.isEmpty ? "Foto" : "Todos")
                            .font(.headline)

                        LazyVGrid(columns: columns, spacing: .spacing(.medium)) {
                            ownPhotoChoice

                            AvatarChoice(
                                photo: nil,
                                name: "Sem foto",
                                isSelected: !usesCustomPhoto && selectedAuthorID == nil
                            ) {
                                select(authorID: nil)
                            }

                            ForEach(authors) { author in
                                AvatarChoice(
                                    photo: author.photo,
                                    name: author.name,
                                    isSelected: !usesCustomPhoto && selectedAuthorID == author.id
                                ) {
                                    select(authorID: author.id)
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
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $pickedItem, matching: .images)
            .onChange(of: pickedItem) {
                guard let pickedItem else { return }
                Task {
                    await loadForCropping(pickedItem)
                }
            }
            .sheet(item: $photoToCrop) { photo in
                ProfilePhotoCropView(image: photo.image) { data in
                    customPhoto = data
                    usesCustomPhoto = true
                }
            }
            .onAppear {
                nickname = profileStore.nickname ?? ""
                selectedAuthorID = profileStore.avatarAuthorID
                customPhoto = profileStore.customPhoto
                usesCustomPhoto = profileStore.customPhoto != nil
                authors = ((try? LocalDatabase.shared.allAuthors()) ?? [])
                    .filter { $0.photo?.isEmpty == false }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        }
    }
}

// MARK: - Own Photo

extension ProfileEditView {

    /// A photo from the library, waiting to be framed.
    struct PhotoToCrop: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    /// First in the grid. With no photo of their own yet, it opens the library; with
    /// one, a tap selects it and a second tap picks another.
    private var ownPhotoChoice: some View {
        Button {
            if customPhoto != nil && !usesCustomPhoto {
                usesCustomPhoto = true
            } else {
                isShowingPhotoPicker = true
            }
        } label: {
            VStack(spacing: .spacing(.xxSmall)) {
                Group {
                    if customPhoto != nil {
                        ProfileAvatarView(photo: nil, customPhoto: customPhoto, size: 64)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: usesCustomPhoto ? 3 : 0)
                }

                Text(usesCustomPhoto ? "Trocar foto" : "Sua foto")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(customPhoto == nil ? "Usar uma foto sua" : (usesCustomPhoto ? "Trocar sua foto" : "Sua foto"))
        .accessibilityAddTraits(usesCustomPhoto ? .isSelected : [])
    }

    private func select(authorID: String?) {
        selectedAuthorID = authorID
        usesCustomPhoto = false
    }

    /// Scaled down on the way in: a camera photo is far bigger than the crop needs, and
    /// the cropper redraws it on every gesture.
    private func loadForCropping(_ item: PhotosPickerItem) async {
        defer { pickedItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longest, 1))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let prepared = await image.byPreparingThumbnail(ofSize: target) ?? image
        photoToCrop = PhotoToCrop(image: prepared)
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
                            isSelected: !usesCustomPhoto && selectedAuthorID == author.id
                        ) {
                            select(authorID: author.id)
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
        let newAuthorID = usesCustomPhoto ? nil : selectedAuthorID
        let newPhoto = usesCustomPhoto ? customPhoto : nil
        let avatarChanged = newAuthorID != profileStore.avatarAuthorID || newPhoto != profileStore.customPhoto
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let nicknameChanged = (trimmed.isEmpty ? nil : trimmed) != profileStore.nickname

        profileStore.update(avatarAuthorID: newAuthorID, nickname: nickname, customPhoto: newPhoto)

        guard avatarChanged || nicknameChanged else { return }
        // Whose photo it is, by name, to see which faces people pick. "própria" for the
        // user's own (never the photo itself), "nenhuma" for "Sem foto".
        let avatar = usesCustomPhoto
            ? "própria"
            : authors.first { $0.id == selectedAuthorID }?.name ?? "nenhuma"
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
