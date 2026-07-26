//
//  HelpView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/05/22.
//

import SwiftUI

struct HelpView: View {

    @State private var isBasicsExpanded: Bool = false
    @State private var isEpisodesExpanded: Bool = false
    @State private var isDifferentiatorsExpanded: Bool = true

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: .spacing(.xxLarge)) {
                    DisclosureGroup(isExpanded: $isBasicsExpanded) {
                        VStack(alignment: .leading, spacing: .spacing(.xxLarge)) {
                            HelpInstructionView(
                                symbol: "play.fill",
                                text: toPlayInstruction
                            )

                            HelpInstructionView(
                                symbol: "square.and.arrow.up",
                                text: toShareInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "magnifyingglass",
                                text: toSearchInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "heart.fill",
                                color: .red,
                                text: favoritesInstruction
                            )
                        }
                        .padding(.top, .spacing(.medium))
                    } label: {
                        Text("O básico")
                            .font(.title)
                            .bold()
                    }

                    DisclosureGroup(isExpanded: $isEpisodesExpanded) {
                        VStack(alignment: .leading, spacing: .spacing(.xxLarge)) {
                            HelpInstructionView(
                                symbol: "play.circle.fill",
                                color: .green,
                                text: episodePlayInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "hand.draw",
                                text: episodeSwipeInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "goforward.30",
                                color: .green,
                                text: episodeControlsInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "arrow.down.circle",
                                color: .green,
                                text: episodeDownloadInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "line.3.horizontal.decrease",
                                text: episodeFilterInstruction
                            )
                        }
                        .padding(.top, .spacing(.medium))
                    } label: {
                        Text("Episódios")
                            .font(.title)
                            .bold()
                    }

                    DisclosureGroup(isExpanded: $isDifferentiatorsExpanded) {
                        VStack(alignment: .leading, spacing: .spacing(.xxLarge)) {
                            HelpInstructionView(
                                symbol: "bookmark.fill",
                                color: .red,
                                text: episodeBookmarkInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "scissors",
                                color: .orange,
                                text: shareClipInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "theatermasks",
                                color: .green,
                                text: reactionsInstruction
                            )
                        }
                        .padding(.top, .spacing(.medium))
                    } label: {
                        Text("Diferenciais do app")
                            .font(.title)
                            .bold()
                    }
                }
                .padding(.horizontal, .spacing(.medium))
                .padding(.top, .spacing(.xSmall))
                .padding(.bottom, .spacing(.xLarge))
            }
        }
        .navigationTitle("Ajuda")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Text

extension HelpView {

    private var toPlayInstruction: String {
        if UIDevice.deviceType == .mac {
            return "Para reproduzir um conteúdo, clique nele 1 vez. Para parar de reproduzir, clique nele novamente."
        } else {
            return "Para reproduzir um conteúdo, toque nele 1 vez. Para parar de reproduzir, toque nele novamente."
        }
    }

    private var toShareInstruction: String {
        if UIDevice.deviceType == .mac {
            return "Para compartilhar, clique com o botão direito no conteúdo e escolha Compartilhar."
        } else {
            return "Para compartilhar, segure o conteúdo por alguns segundos até o menu de contexto abrir e escolha Compartilhar."
        }
    }

    private var toSearchInstruction: String {
        let appendix = "A pesquisa inclui todos os conteúdos do app e é tolerante a alguns erros de escrita."
        switch UIDevice.deviceType {
        case .iPhone:
            return "Para pesquisar, toque na lupa no canto inferior direito da tela a qualquer momento.\n\n\(appendix)"
        case .iPad:
            return "Para pesquisar por conteúdos, toque em Buscar na barra lateral.\n\n\(appendix)"
        case .mac:
            return "Para pesquisar por conteúdos, selecione Buscar na barra lateral.\n\n\(appendix)"
        }
    }

    private var favoritesInstruction: String {
        switch UIDevice.deviceType {
        case .iPhone:
            "Para favoritar, segure o conteúdo e escolha Favoritar.\n\nPara ver apenas as favoritas, toque no coração nos filtros da parte superior da tela."
        case .iPad:
            "Para favoritar, segure o conteúdo e escolha Favoritar.\n\nPara ver apenas as favoritas, toque em Favoritas na barra lateral."
        case .mac:
            "Para favoritar, clique com o botão direito em um conteúdo e escolha Favoritar.\n\nPara ver apenas as favoritas, clique em Favoritas na barra lateral."
        }
    }
    // MARK: - Episodes

    private var episodePlayInstruction: String {
        "Toque em um episódio para ver os detalhes. Toque no botão de Play ao lado de cada episódio para reproduzir.\n\nUma barra aparece na parte inferior, toque nela para abrir a tela Reproduzindo Agora com a capa, o progresso e os controles."
    }

    private var episodeControlsInstruction: String {
        "Na tela Reproduzindo Agora, arraste a barra de progresso para pular para qualquer ponto. Use os botões para voltar 15 segundos ou avançar 30 segundos.\n\nO progresso é salvo automaticamente. Se você sair e voltar, a reprodução continua de onde parou."
    }

    private var episodeBookmarkInstruction: String {
        "Enquanto ouve, toque em \"Marcar Esse Ponto\" para salvar o momento atual. Os marcadores aparecem como linhas vermelhas na barra de progresso e em uma lista abaixo.\n\nToque no Play ao lado de qualquer marcador para pular até aquele ponto novamente. Você também pode dar um nome, adicionar uma nota e excluir marcadores tocando em um deles."
    }

    private var episodeDownloadInstruction: String {
        "Todo episódio selecionado para reprodução é primeiro baixado offline antes de reproduzir. Uma vez baixado, ele toca sem internet.\n\nPara apagar o download, abra os detalhes do episódio, toque na lixeira ao lado do tamanho do arquivo e confirme."
    }

    private var episodeFilterInstruction: String {
        "A lista de episódios tem filtros horizontais e de menu que podem ser combinados. Na parte superior: Todos, Favoritos e Com Marcadores.\n\nNo menu do canto direito você pode filtrar por estado de reprodução (Não Iniciado, Em Progresso, Finalizado).\n\nUse as opções de ordenação para ver os mais recentes ou mais antigos primeiro."
    }

    private var episodeSwipeInstruction: String {
        "Deslize um episódio para a direita para favoritar ou desfavoritar. Deslize para a esquerda para marcar como finalizado ou desfazer."
    }

    // MARK: - Differentiators

    private var shareClipInstruction: String {
        "Enquanto ouve um episódio, toque em \"Compartilhar Trecho\" para escolher um pedaço específico do áudio e compartilhá-lo como vídeo.\n\nArraste a forma de onda para os lados para selecionar o trecho exato que você quer compartilhar."
    }

    private var reactionsInstruction: String {
        "As Reações são um jeito diferente de descobrir as vírgulas sonoras: escolha uma categoria e responda rápido com a vírgula perfeita.\n\nSegure em uma reação e escolha \"Fixar no Topo\" para acessá-la facilmente, ou toque em compartilhar para enviar o link dela a um amigo."
    }
}

// MARK: - Subviews

extension HelpView {

    struct HelpInstructionView: View {

        let symbol: String
        var color: Color = .accentColor
        let iconFrameWidth: CGFloat = 40
        let text: String

        var body: some View {
            HStack {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundColor(color)
                    .frame(width: iconFrameWidth)
                    .padding(.leading, .spacing(.xxxSmall))
                    .padding(.trailing, .spacing(.xSmall))

                Text(text)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HelpView()
    }
}
