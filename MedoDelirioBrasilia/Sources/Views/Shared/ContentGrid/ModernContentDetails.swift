//
//  ModernContentDetails.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 03/06/26.
//

import SwiftUI

struct ModernContentDetails: View {

    let content: any MedoContentProtocol

    private let shapeCornerRadius: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: .spacing(.small)) {
                Text(content.title)
                    .fontDesign(.rounded)
                    .font(.body)

                HStack(spacing: .spacing(.small)) {
                    if content.type == .song {
                        Image(systemName: "music.quarternote.3")
                            .foregroundStyle(.primary)
                    }

                    Text(content.subtitle.uppercased())
                        .fontDesign(.monospaced)
                        .foregroundStyle(
                            colorScheme == .dark ?
                                .primary : content.primaryColor.darkened(by: 0.5)
                        )
                        .font(.caption)
                        .foregroundColor(.primary.opacity(colorScheme == .dark ? 0.5 : 0.5))
                        .bold()
                        .lineLimit(2)

                    Text(content.duration.minuteSecondFormatted)
                        .fontDesign(.monospaced)
                        .foregroundStyle(
                            colorScheme == .dark ?
                                .primary : content.primaryColor.darkened(by: 0.5)
                        )
                        .font(.caption)
                        .foregroundColor(.primary.opacity(colorScheme == .dark ? 0.5 : 0.5))
                        .bold()
                }
            }

            Spacer()
        }
        .frame(minWidth: 260, maxWidth: 320)
        .padding(.vertical, .spacing(.xLarge))
        .padding(.leading, .spacing(.medium))
        .background {
            RoundedRectangle(cornerRadius: shapeCornerRadius, style: .continuous)
                .fill(
                    colorScheme == .dark ?
                    content.primaryColor.opacity(0.33) : content.primaryColor.darkened(by: 0.3).opacity(0.2)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: shapeCornerRadius)
                        .stroke(
                            content.primaryColor.opacity(colorScheme == .dark ? 1 : 0.7),
                            lineWidth: 1
                        )
                }
        }
    }
}

//#Preview {
//    ModernContentDetails()
//}
