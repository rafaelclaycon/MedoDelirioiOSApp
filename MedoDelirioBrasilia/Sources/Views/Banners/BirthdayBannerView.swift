//
//  BirthdayBannerView.swift
//  MedoDelirioBrasilia
//

import SwiftUI

struct BirthdayBannerView: View {

    @State private var showBirthdayView = false

    var body: some View {
        Button {
            showBirthdayView = true
        } label: {
            HStack(alignment: .center, spacing: .spacing(.medium)) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)

                Text("O app faz 4 anos!")
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, .spacing(.medium))
            .padding(.vertical, .spacing(.medium))
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "E91E8C"), Color(hex: "F472B6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBirthdayView) {
            FourthBirthdayView()
        }
    }
}

#Preview {
    BirthdayBannerView()
        .padding()
}
