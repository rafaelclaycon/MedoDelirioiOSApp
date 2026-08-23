//
//  EmptyFolderView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/05/22.
//

import SwiftUI

struct EmptyFolderView: View {

    var body: some View {
        ContentUnavailableView(
            "Tá Ouvindo Isso?",
            systemImage: "speaker.zzz",
            description: Text("Nós também não. Volte para os sons, segure em um deles e escolha Adicionar a Pasta para adicioná-lo aqui.")
        )
    }
}

// MARK: - Preview

#Preview {
    EmptyFolderView()
}
