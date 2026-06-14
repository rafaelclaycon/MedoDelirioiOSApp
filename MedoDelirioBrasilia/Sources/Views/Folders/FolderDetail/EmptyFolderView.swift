//
//  EmptyFolderView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/05/22.
//

import SwiftUI

struct EmptyFolderView: View {

    var body: some View {
        VStack(alignment: .center, spacing: .spacing(.large)) {
            Image(systemName: "speaker.zzz")
                .font(.system(size: 70))
                .foregroundColor(.gray)
                .frame(width: 100)
                .opacity(0.5)
            
            Text("Tá Ouvindo Isso?")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            
            Text("Nós também não. Volte para os sons, segure em um deles e escolha Adicionar a Pasta para adicioná-lo aqui.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, UIDevice.deviceType == .iPhone ? 15 : 40)
        }
    }
}

// MARK: - Preview

#Preview {
    EmptyFolderView()
}
