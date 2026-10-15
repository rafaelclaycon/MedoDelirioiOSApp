//
//  ShareImageFormat.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 15/10/26.
//

import SwiftUI

/// The shapes a shareable picture comes in: the election count, a game's result.
enum ShareImageFormat: String, CaseIterable, Identifiable {

    /// Feed posts and chats.
    case square
    /// Instagram and WhatsApp stories.
    case stories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: "Quadrada"
        case .stories: "Stories (9:16)"
        }
    }

    /// Rendered at 3x: 1080 × 1080 and 1080 × 1920.
    var size: CGSize {
        switch self {
        case .square: CGSize(width: 360, height: 360)
        case .stories: CGSize(width: 360, height: 640)
        }
    }

    /// Instagram covers roughly the top and bottom 13% of a story (250 px of 1920) with
    /// its own controls, so content keeps clear of them.
    static let storiesSafeVerticalPadding: CGFloat = 84
}

/// Asks people posting to Stories to tag the podcast, and optionally to add a link to
/// download the app. Each is a row that copies it, since typing them into Instagram's
/// stickers is a chore.
struct StoriesTagCallout: View {

    static let instagramHandle = "@medoedelirioembrasiliapodcast"
    /// The App Store page in its short form, which opens in any country's store.
    static let appStoreLink = "https://apps.apple.com/br/app/id1625199878"

    let tint: Color
    /// Pictures that leave room for Instagram's link sticker offer the link too.
    var offersAppLink: Bool = false

    var body: some View {
        VStack(spacing: .spacing(.small)) {
            Text("Vai postar nos Stories?")
                .font(.subheadline.weight(.semibold))

            CopyRow(
                systemImage: "at",
                title: "Marque o podcast",
                value: Self.instagramHandle,
                tint: tint,
                accessibilityHint: "Copia o nome da conta do podcast no Instagram"
            )

            if offersAppLink {
                CopyRow(
                    systemImage: "link",
                    title: "Link pra baixar o app",
                    value: Self.appStoreLink,
                    displayValue: Self.appStoreLink.replacingOccurrences(of: "https://", with: ""),
                    tint: tint,
                    accessibilityHint: "Copia o link do app na App Store, para o adesivo de link"
                )
            }
        }
    }
}

extension StoriesTagCallout {

    /// A full-width row: what it is, the value in gray, and a copy symbol that turns into
    /// a checkmark for a couple of seconds after a tap. Symbol only, so the value gets
    /// the room.
    struct CopyRow: View {

        let systemImage: String
        let title: String
        let value: String
        var displayValue: String? = nil
        let tint: Color
        let accessibilityHint: String

        @State private var copied = false

        var body: some View {
            Button {
                UIPasteboard.general.string = value
                HapticFeedback.success()
                copied = true
            } label: {
                HStack(spacing: .spacing(.medium)) {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(displayValue ?? value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: .spacing(.small))

                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tint)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 24)
                }
                .padding(.horizontal, .spacing(.medium))
                .padding(.vertical, .spacing(.small))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemFill))
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title): \(displayValue ?? value)")
            .accessibilityValue(copied ? "Copiado" : "")
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(.isButton)
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }
    }
}
