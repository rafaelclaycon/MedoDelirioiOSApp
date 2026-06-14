//
//  NoFoldersView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/11/22.
//

import SwiftUI

struct NoFoldersView: View {
    
    private var text: String {
        switch UIDevice.deviceType {
        case .iPhone:
            "Toque no + no canto superior direito para criar uma nova pasta de sons."
        case .iPad:
            "Toque em Nova Pasta acima para criar uma nova pasta de sons."
        case .mac:
            "Clique em Nova Pasta acima para criar uma nova pasta de sons."
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            NoFoldersSymbol()
            
            Text("Nenhuma Pasta Criada (Ainda)")
                .font(.title3)
                .bold()
                .multilineTextAlignment(.center)
            
            Text("Pastas são uma maneira de organizar conteúdos que você usa com frequência para acesso fácil.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(text)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

struct NoFoldersView_Previews: PreviewProvider {

    static var previews: some View {
        NoFoldersView()
    }
}
