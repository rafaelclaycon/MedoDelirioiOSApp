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

    @Environment(\.usesSidebarLayout) private var usesSidebarLayout

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
                            // `.primary` resolves to the tint inside the disclosure
                            // button; a concrete color doesn't.
                            .foregroundStyle(Color(uiColor: .label))
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
                            // `.primary` resolves to the tint inside the disclosure
                            // button; a concrete color doesn't.
                            .foregroundStyle(Color(uiColor: .label))
                    }

                    DisclosureGroup(isExpanded: $isDifferentiatorsExpanded) {
                        VStack(alignment: .leading, spacing: .spacing(.xxLarge)) {
                            HelpInstructionView(
                                symbol: "list.bullet.indent",
                                color: .purple,
                                tag: .notOnSpotify,
                                text: chaptersInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "scissors",
                                color: .orange,
                                tag: .notOnSpotify,
                                text: shareClipInstruction
                            )

                            Divider()

                            HelpInstructionView(
                                symbol: "bookmark.fill",
                                color: .red,
                                tag: .betterThanSpotify,
                                text: episodeBookmarkInstruction
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
                            // `.primary` resolves to the tint inside the disclosure
                            // button; a concrete color doesn't.
                            .foregroundStyle(Color(uiColor: .label))
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
        if UIDevice.deviceType == .mac {
            return "Para pesquisar por conteúdos, selecione Buscar na barra lateral.\n\n\(appendix)"
        } else if usesSidebarLayout {
            return "Para pesquisar por conteúdos, toque em Buscar na barra lateral.\n\n\(appendix)"
        } else {
            return "Para pesquisar, toque na lupa no canto inferior direito da tela a qualquer momento.\n\n\(appendix)"
        }
    }

    private var favoritesInstruction: String {
        if UIDevice.deviceType == .mac {
            "Para favoritar, clique com o botão direito em um conteúdo e escolha Favoritar.\n\nPara ver apenas as favoritas, clique em Favoritas na barra lateral."
        } else if usesSidebarLayout {
            "Para favoritar, segure o conteúdo e escolha Favoritar.\n\nPara ver apenas as favoritas, toque em Favoritas na barra lateral."
        } else {
            "Para favoritar, segure o conteúdo e escolha Favoritar.\n\nPara ver apenas as favoritas, toque no coração nos filtros da parte superior da tela."
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
        let toDelete = if UIDevice.deviceType == .mac {
            "Para excluir, clique com o botão direito no marcador e escolha Excluir."
        } else if canSwipeBookmarks {
            "Para excluir, arraste o marcador para a esquerda."
        } else {
            "Para excluir, segure o marcador e escolha Excluir."
        }
        return "Enquanto ouve, toque no símbolo de marcador na tela Reproduzindo Agora para salvar o momento atual. Os marcadores aparecem como linhas vermelhas na barra de progresso e na aba Marcadores.\n\nNa aba, toque no Play ao lado de um marcador para voltar até aquele ponto, ou toque no marcador para dar um título e escrever uma anotação. \(toDelete)"
    }

    /// Mirrors `if_swipeActionsContainer`: swiping a bookmark needs both the iOS 27
    /// SDK at build time and iOS 27 at run time. Without either, holding it is the
    /// only way to delete.
    private var canSwipeBookmarks: Bool {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return true
        }
        #endif
        return false
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

    private var chaptersInstruction: String {
        "Os capítulos dividem cada episódio por assunto. Na tela Reproduzindo Agora, as setas ao lado do título pulam para o capítulo anterior ou para o próximo, e o botão de avançar mostra quanto falta para o capítulo atual acabar.\n\nToque no título do capítulo, ou abra a aba Capítulos, para ver a lista completa e ir direto para qualquer um deles. Segure um capítulo para compartilhá-lo como clipe.\n\nOs capítulos são gerados por IA e podem conter erros. Para escondê-los, vá em Configurações › Episódios."
    }

    private var shareClipInstruction: String {
        "Enquanto ouve, toque no símbolo da tesoura na tela Reproduzindo Agora para transformar um trecho do episódio em vídeo.\n\nEscolha o trecho pela forma de onda, arrastando para os lados, ou pela transcrição, tocando na primeira e na última linha. Na transcrição, toque no título de um capítulo para selecionar o capítulo inteiro.\n\nEmbaixo da duração, o app mostra em quais redes o clipe cabe, como Stories, Reels e X, para você não ter surpresa na hora de postar. Um clipe pode ter até \(SocialVideoLimit.formatted(SocialVideoLimit.longest))."
    }

    private var reactionsInstruction: String {
        "As Reações são um jeito diferente de descobrir as vírgulas sonoras: escolha uma categoria e responda rápido com a vírgula perfeita.\n\nSegure em uma reação e escolha \"Fixar no Topo\" para acessá-la facilmente, ou toque em compartilhar para enviar o link dela a um amigo."
    }
}

// MARK: - Subviews

extension HelpView {

    /// Why a differentiator is worth listening here rather than on Spotify, where the
    /// show has far more listeners. Only for claims checked against Spotify's app.
    enum SpotifyComparisonTag {
        case notOnSpotify
        case betterThanSpotify

        var label: String {
            switch self {
            case .notOnSpotify: "NÃO TEM NO SPOTIFY"
            case .betterThanSpotify: "MELHOR QUE O SPOTIFY"
            }
        }

        /// Spotify's green ties "not on Spotify" to the brand at a glance.
        var color: Color {
            switch self {
            case .notOnSpotify: .spotifyGreen
            case .betterThanSpotify: .red
            }
        }
    }

    struct HelpInstructionView: View {

        let symbol: String
        var color: Color = .accentColor
        var tag: SpotifyComparisonTag? = nil
        /// Fits every symbol here at `.largeTitle` except the wide theater masks, so
        /// the text lines up across rows.
        let iconFrameWidth: CGFloat = 56
        let text: String

        var body: some View {
            HStack {
                // A symbol wider than the column steps down a size instead of
                // spilling past it and getting cut off at the screen edge.
                ViewThatFits(in: .horizontal) {
                    Image(systemName: symbol)
                        .font(.largeTitle)
                    Image(systemName: symbol)
                        .font(.title)
                }
                .foregroundStyle(color)
                .frame(width: iconFrameWidth)
                .padding(.leading, .spacing(.xxxSmall))
                .padding(.trailing, .spacing(.xSmall))

                VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                    if let tag {
                        Text(tag.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tag.color)
                            .padding(.horizontal, .spacing(.xSmall))
                            .padding(.vertical, .spacing(.xxxSmall))
                            .background(tag.color.opacity(0.15), in: Capsule())
                    }

                    Text(text)
                }
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
