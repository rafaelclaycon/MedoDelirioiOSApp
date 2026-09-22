//
//  PrivacySettingsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/10/22.
//

import SwiftUI

struct PrivacySettingsView: View {

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TrendsSettingsView()) {
                    Label("Tendências", systemImage: "chart.line.uptrend.xyaxis")
                }
                
                NavigationLink(
                    destination: FolderResearchSettingsView()
                ) {
                    Label {
                        Text("Pesquisa Sobre as Pastas")
                    } icon: {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                    }
                }
            }

            Section {
                Button {
                    OpenUtility.open(link: "https://site.medodelirioios.com/#politica-de-privacidade")
                } label: {
                    Label("Política de Privacidade", systemImage: "doc.text")
                }
            } footer: {
                Text("Inclui detalhes sobre o uso de IA para gerar transcrições e capítulos dos episódios.")
            }
        }
        .navigationTitle("Privacidade")
        .navigationBarTitleDisplayMode(.inline)
    }

}

struct PrivacySettingsView_Previews: PreviewProvider {

    static var previews: some View {
        PrivacySettingsView()
    }

}
