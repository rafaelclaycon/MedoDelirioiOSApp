//
//  WhatsAppLinkBubble.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 31/05/26.
//

import Kingfisher
import SwiftUI

struct WhatsAppLinkBubble: View {

    let reaction: Reaction
    let subtitle: String?
    let time: String

    @Environment(\.colorScheme) private var colorScheme

    init(reaction: Reaction, subtitle: String? = nil, time: String) {
        self.reaction = reaction
        self.subtitle = subtitle
        self.time = time
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .white.opacity(0.15) : .black.opacity(0.12)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 0) {
                KFImage(URL(string: reaction.image))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()

                VStack(alignment: .leading, spacing: 3) {
                    Text(reaction.title.capitalized(with: Locale(identifier: "pt_BR")))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.6))
                        Text("medodelirioios.com")
                            .font(.system(size: 11))
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                    .padding(.top, subtitle != nil ? 4 : 0)

                    HStack {
                        Spacer()
                        Text(time)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
            )
            .shadow(color: shadowColor, radius: 3, x: 0, y: 1)
            .frame(maxWidth: 280)

            Image(systemName: "arrowshape.turn.up.right.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .padding(8)
                .background(.gray.opacity(0.5))
                .clipShape(Circle())
        }
    }
}

// MARK: - Preview

#Preview {
    WhatsAppLinkBubble(
        reaction: .classicsMock,
        subtitle: "20 sons nesta reação",
        time: "18:05"
    )
    .padding()
    .background(Color(red: 0.84, green: 0.92, blue: 0.83))
}
