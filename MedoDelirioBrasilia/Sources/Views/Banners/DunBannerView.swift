//
//  DunBannerView.swift
//  MedoDelirioBrasilia
//

import SwiftUI

private let dunAppStoreURL = "https://apps.apple.com/br/app/d%C3%B9n-private-link-storage/id6627333601"

struct DunBannerView: View {

    @Binding var isBeingShown: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: .spacing(.medium)) {
            Image("DunAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            Text("Seus links, protegidos pelo \(UIDevice.biometricsName).")
                .bold()
                .fontDesign(.serif)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Spacer()

            Button {
                OpenUtility.open(link: dunAppStoreURL)
            } label: {
                Text("Ver")
                    .font(.subheadline.bold())
                    .padding(.horizontal, .spacing(.xSmall))
                    .padding(.vertical, .spacing(.xxxSmall))
            }
            .tint(.white)
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)

            Button {
                AppPersistentMemory.shared.setHasDismissedDunBanner(to: true)
                isBeingShown = false
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.all, .spacing(.xxSmall))
            }
            .accessibilityLabel("Fechar")
        }
        .padding(.horizontal, .spacing(.medium))
        .padding(.vertical, .spacing(.medium))
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "7C3AED"), Color(hex: "9F67FF")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

#Preview {
    DunBannerView(isBeingShown: .constant(true))
        .padding()
}
