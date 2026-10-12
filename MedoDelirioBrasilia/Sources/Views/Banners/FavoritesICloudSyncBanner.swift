//
//  FavoritesICloudSyncBanner.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// Tells people on the Favorites screen that favorites now sync through iCloud, and where
/// to turn it off. Version 13.5 brought favorites sync so soon after 13.4's What's New that
/// a banner here says it without another full-screen interruption.
///
/// Shows only while sync is on, until dismissed.
struct FavoritesICloudSyncBanner: View {

    @State private var isShown = UserSettings().getEnableICloudSync()
        && !AppPersistentMemory.shared.hasDismissedFavoritesICloudSyncBanner()

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isShown {
            VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                Label("Favoritas no iCloud", systemImage: "icloud")
                    .foregroundStyle(.red)
                    .bold()

                Text("Suas vírgulas e músicas favoritas agora sincronizam com seus outros aparelhos pelo iCloud. Para desativar, vá em Você > Seus aparelhos.")
                    .foregroundStyle(.red)
                    .opacity(0.8)
                    .font(.callout)
                    .padding(.trailing, .spacing(.large))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.all, 20)
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .foregroundStyle(.red)
                    .opacity(colorScheme == .dark ? 0.3 : 0.15)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    AppPersistentMemory.shared.setHasDismissedFavoritesICloudSyncBanner(to: true)
                    withAnimation {
                        isShown = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Fechar")
                .padding()
            }
            // Inside the `if`, so a dismissed banner leaves no gap above the favorites.
            .padding(.top, .spacing(.xxxSmall))
            .padding(.bottom, .spacing(.small))
        }
    }
}

#Preview {
    FavoritesICloudSyncBanner()
        .padding()
}
