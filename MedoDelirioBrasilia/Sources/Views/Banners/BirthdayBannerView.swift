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
                Image(systemName: "balloon.2")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)

                Text("Uma mensagem especial do Cristiano")
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer()
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
