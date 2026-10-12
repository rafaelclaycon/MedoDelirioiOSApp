//
//  ProfileAvatarView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI
import Kingfisher

/// The user's avatar: an author's photo in a circle, or a person symbol until they
/// pick one.
struct ProfileAvatarView: View {

    let photo: String?
    var size: CGFloat = 72

    private var photoURL: URL? {
        guard let photo, !photo.isEmpty else { return nil }
        return URL(string: photo)
    }

    var body: some View {
        Group {
            if let photoURL {
                KFImage(photoURL)
                    .placeholder {
                        placeholder
                    }
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// Solid, so it doesn't let the hero's green show through.
    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color(.systemGray3))
    }
}

#Preview {
    HStack {
        ProfileAvatarView(photo: nil)
        ProfileAvatarView(photo: nil, size: 40)
    }
}
