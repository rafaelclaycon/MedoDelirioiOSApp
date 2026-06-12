//
//  ProcessingView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 21/08/22.
//

import SwiftUI

struct ProcessingView: View {

    let message: String
    var progressViewYOffset: CGFloat = -20
    var progressViewWidth: CGFloat = 200
    var messageYOffset: CGFloat = 33

    var body: some View {
        ZStack {
            ProgressView()
                .scaleEffect(2, anchor: .center)
                .frame(width: progressViewWidth, height: 140)
                .offset(x: 0, y: progressViewYOffset)
                .background(.regularMaterial)
                .cornerRadius(25)
            
            Text(message)
                .offset(x: 0, y: messageYOffset)
                .multilineTextAlignment(.center)
        }
    }

}

#Preview {
    VStack(spacing: .spacing(.xLarge)) {
        ProcessingView(
            message: Shared.ShareAsVideo.generatingVideoLongMessage,
            progressViewYOffset: -27,
            progressViewWidth: 270,
            messageYOffset: 30
        )
    }
}
