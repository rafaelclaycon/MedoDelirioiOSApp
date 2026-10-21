//
//  SyncInfoView+KnowMoreView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 19/08/23.
//

import SwiftUI

extension ContentUpdateStatusView {

    struct KnowMoreView: View {

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: .spacing(.large)) {
                        MSTWordmark()
                        MSTMotto()
                    }
                    .mstBanner()
                    .padding(.bottom, .spacing(.xSmall))

                    Text("O que é?")
                        .font(.title2)
                        .bold()

                    Text("O M.S.T. (Medo Sync Technology) é o sistema de atualização de conteúdos do app Medo e Delírio. Ele baixa e atualiza os dados do app automaticamente quando o seu \(UIDevice.deviceGenericName) está conectado à Internet. O consumo de dados é baixíssimo (na casa dos poucos MBs) e é oferecido sem custo para os usuários.")

                    Text("Histórico")
                        .font(.title2)
                        .bold()

                    Text("Quando o app foi lançado em maio de 2022, os sons eram colocados dentro do pacote do app, tornando obrigatório que o app fosse atualizado para que novos conteúdos chegassem ao público.\n\nA partir de setembro de 2023, com a introdução do sistema de atualização na versão 7, novos sons aparecem automaticamente na lista ao abrir o app.\n\nAcabava assim a obrigação de atualizar o app na App Store para receber novos conteúdos.")

                    Text("Por que M.S.T.?")
                        .font(.title2)
                        .bold()

                    Text("É uma homenagem ao Movimento dos Trabalhadores Rurais Sem Terra. Antes do sistema, os sons não tinham chão próprio: dependiam de uma versão nova na App Store para chegar até você. Com o M.S.T., eles ocuparam o caminho direto até o seu \(UIDevice.deviceGenericName).")

                    Text("Importância")
                        .font(.title2)
                        .bold()

                    Text("O sistema de atualização de dados do app, do servidor ao app até o sistema de subir arquivos para o servidor, foi desenvolvido por mim usando a linguagem **Swift**.")

                    HStack {
                        Spacer()

                        Image(decorative: "swiftLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                        Spacer()
                    }
                    .padding(.bottom, 3)

                    Text("Verificar se isso era possível foi tema do meu Projeto Final do curso de Análise e Desenvolvimento de Sistemas e é inovador por Swift ser majoritariamente uma linguagem de *front-end* (usada para fazer as telas com as quais você está interagindo) e não *back-end* (a parte dos servidores que armazenam e entregam os dados pro app).\n\nObrigado a todos que participaram da fase Beta e responderam ao questionário! A participação de vocês foi crítica para o sucesso do projeto. ❤️")

                    HStack {
                        Spacer()
                        GlassButton(symbol: "book.pages", title: "Leia mais no blogue", color: .blue) {
                            OpenUtility.open(link: "https://www.fromrafaelwithco.de/thank-you-bolsonaro-part-1/")
                        }
                        Spacer()
                    }

                    Text("Todos os códigos relacionados ao app são abertos e estão disponíveis para estudo e colaboração.")

                    HStack {
                        Spacer()
                        GlassButton(symbol: "laptopcomputer", title: "Ver no GitHub", color: .purple) {
                            OpenUtility.open(link: "https://github.com/rafaelclaycon")
                        }
                        Spacer()
                    }
                }
                .padding(.vertical)
                .padding(.horizontal, 30)
            }
            .navigationTitle("Sobre o M.S.T.")
            .onAppear {
                Task {
                    await AnalyticsService().send(action: "didViewSyncSystemAboutScreen")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentUpdateStatusView.KnowMoreView()
}
