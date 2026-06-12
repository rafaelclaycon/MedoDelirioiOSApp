//
//  FolderResearchSettings.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/10/22.
//

import SwiftUI

struct FolderResearchSettingsView: View {

    @StateObject private var viewModel = ViewModel()

    // MARK: - View Body

    var body: some View {
        Form {
            Section {
                Toggle("Participar da Pesquisa", isOn: $viewModel.hasJoinedFolderResearch)
                    .onChange(of: viewModel.hasJoinedFolderResearch) { _, enroll in
                        Task {
                            await viewModel.onEnrollOptionChanged(enroll)
                        }
                    }
            } footer: {
                Text(
                    "Nenhum dado coletado identifica você.\n\nAo enviar informações das suas pastas anonimamente, você me ajuda a entender o uso dessa funcionalidade para que eu possa melhorá-la no futuro.\n\nA pesquisa consiste em enviar os seguintes dados para o servidor do Medo e Delírio iOS:\n · ID de instalação do app (não contém nenhum nome; é renovado ao desintalar e reinstalar o app);\n · símbolo, cor e nome das pastas;\n · IDs dos sons inseridos nas pastas.\n\nNenhum som será enviado, portanto o consumo de dados será baixíssimo."
                )
            }

            switch viewModel.state {
            case .enrolled:
                Section {
                    Text("Data do último envio: \(viewModel.lastSendDate)")
                }

            case .notEnrolled:
                EmptyView()

            case .sendingInfo:
                SendingView()

            case .errorSending:
                ErrorView()
            }

//            Section {
//                Button("Solicitar a exclusão dos meus dados") {
//                    //showEmailClientConfirmationDialog = true
//                }
//            }
        }
        .navigationTitle("Pesquisa Sobre as Pastas")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onViewLoaded()
        }
    }

}

// MARK: - Subviews

extension FolderResearchSettingsView {

    struct SendingView: View {

        var body: some View {
            VStack(spacing: 28) {
                ProgressView()
                    .scaleEffect(1.4, anchor: .center)

                Text("ENVIANDO INFORMAÇÕES...")
                    .font(.callout)
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }

    struct ErrorView: View {

        var body: some View {
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)

                Text("Não Foi Possível Enviar os Dados")
                    .multilineTextAlignment(.center)
                    .font(.title3)

                Text("Não se preocupe, o app tentará enviar novamente no futuro. Você não precisa fazer mais nada.")
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .padding(.horizontal)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

#Preview {
    FolderResearchSettingsView()
}
