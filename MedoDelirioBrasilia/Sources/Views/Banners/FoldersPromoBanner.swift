//
//  FoldersPromoBanner.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/08/26.
//

import SwiftUI

/// Folders are useful but easy to miss, since they only surface from a long-press on
/// a sound. This surfaces them from a screen users already visit often.
///
/// Orange, deliberately not blue — the color already in use for the pin-reactions
/// tip on this same screen, and the two can appear stacked together.
struct FoldersPromoBanner: View {

    @Binding var isBeingShown: Bool

    /// Takes the user to Vírgulas > Pastas. A closure, not a navigation destination
    /// this view owns itself, since Reações has no notion of the other tab.
    let goToFolders: () -> Void

    @Environment(\.colorScheme) var colorScheme

    /// Plain `.orange` reads as washed out against the light-mode background's low
    /// opacity fill — `.darkerOrange` (already in the palette, previously unused)
    /// gives it real contrast there. Dark mode keeps the system color.
    private var foregroundColor: Color {
        colorScheme == .dark ? .orange : .darkerOrange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tem 1 min pra ouvir sobre as Pastas?")
                    .foregroundColor(foregroundColor)
                    .bold()
                    .multilineTextAlignment(.leading)

                Spacer()
            }

            Text("Separe seus sons favoritos em Pastas, como se fossem Reações personalizadas. Por assunto, por vibe, do jeito que você quiser.")
                .foregroundColor(foregroundColor)
                .opacity(0.8)
                .font(.callout)

            Button {
                Task {
                    await AnalyticsService().send(
                        originatingScreen: "FoldersPromoBanner",
                        action: "didTapViewFolders"
                    )
                }
                dismiss()
                goToFolders()
            } label: {
                Text("Ver Pastas")
                    .padding(.horizontal)
            }
            .font(.body)
            .tint(foregroundColor)
            .controlSize(.regular)
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .padding(.top, 2)
        }
        .padding(.all, 20)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.orange)
                .opacity(colorScheme == .dark ? 0.3 : 0.15)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Task {
                    await AnalyticsService().send(
                        originatingScreen: "FoldersPromoBanner",
                        action: "didDismiss"
                    )
                }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(foregroundColor)
            }
            .padding()
        }
    }

    private func dismiss() {
        AppPersistentMemory.shared.setHasSeenFoldersPromoBanner(to: true)
        isBeingShown = false
    }
}

#Preview {
    FoldersPromoBanner(isBeingShown: .constant(true), goToFolders: {})
}
