import UIKit

struct Shared {

    struct TabInfo {

        static func name(_ type: PhoneTab) -> String {
            switch type {
            case .sounds:
                "Vírgulas"
            case .reactions:
                "Reações"
            case .episodes:
                "Tendências"
            case .settings:
                "Configurações"
            case .search:
                "Pesquisar"
            }
        }

        static func symbol(_ type: PhoneTab) -> String {
            switch type {
            case .sounds:
                "quote.bubble"
            case .reactions:
                "theatermasks"
            case .episodes:
                "chart.line.uptrend.xyaxis"
            case .settings:
                ""
            case .search:
                "magnifyingglass"
            }
        }

        static func name(_ type: PadScreen) -> String {
            switch type {
            case .allSounds:
                "Vírgulas"
            case .favorites:
                "Favoritos"
            case .groupedByAuthor:
                "Autores"
            case .reactions:
                "Reações"
            case .trends:
                "Tendências"
            case .allFolders:
                "Todas as Pastas"
            default:
                ""
            }
        }

        static func symbol(_ type: PadScreen) -> String {
            switch type {
            case .allSounds:
                "quote.bubble"
            case .favorites:
                "heart"
            case .groupedByAuthor:
                "person"
            case .reactions:
                "theatermasks"
            case .trends:
                "chart.line.uptrend.xyaxis"
            case .allFolders:
                "folder"
            default:
                ""
            }
        }
    }

    struct Constants {
        static let toastViewBottomPaddingPhone: CGFloat = 60
        static let toastViewBottomPaddingPad: CGFloat = 15
        static let soundCountPhoneBottomPadding: CGFloat = 50
        static let soundCountPadBottomPadding: CGFloat = 4
    }

    struct ActivityTypes {
        
        static let playAndShareSounds = "com.rafaelschmitt.MedoDelirioBrasilia.PlayAndShareSounds"
        static let viewCollections = "com.rafaelschmitt.MedoDelirioBrasilia.ViewCollections"
        static let playAndShareSongs = "com.rafaelschmitt.MedoDelirioBrasilia.PlayAndShareSongs"
        static let viewLast24HoursTopChart = "com.rafaelschmitt.MedoDelirioBrasilia.ViewLast24HoursTopChart"
        static let viewLast3DaysTopChart = "com.rafaelschmitt.MedoDelirioBrasilia.ViewLast3DaysTopChart"
        static let viewLastWeekTopChart = "com.rafaelschmitt.MedoDelirioBrasilia.ViewLastWeekTopChart"
        static let viewLastMonthTopChart = "com.rafaelschmitt.MedoDelirioBrasilia.ViewLastMonthTopChart"
        static let view2026TopChart = "com.rafaelschmitt.MedoDelirioBrasilia.View2026TopChart"
        static let view2025TopChart = "com.rafaelschmitt.MedoDelirioBrasilia.View2025TopChart"
        static let view2024TopChart = "com.rafaelschmitt.MedoDelirioBrasilia.View2024TopChart"
        static let view2023TopChart = "com.rafaelschmitt.MedoDelirioBrasilia.View2023TopChart"
        static let view2022TopChart = "com.rafaelschmitt.MedoDelirioBrasilia.View2022TopChart"
        static let viewAllTimeTopChart = "com.rafaelschmitt.MedoDelirioBrasilia.ViewAllTimeTopChart"
    }
    
    static let addToFolderButtonText = "Adicionar a Pasta"
    static let shareSoundButtonText = "Compartilhar"
    static let shareSongButtonText = "Compartilhar Música"
    static let shareAsVideoButtonText = "Compartilhar como Vídeo"
    static let addToFavorites = "Adicionar aos Favoritos"
    static let removeFromFavorites = "Remover dos Favoritos"
    
    struct SoundSelection {
        
        static let selectSounds = "Selecionar"
        static let soundSelectedSingular = "1 Selecionado"
        static let soundsSelectedPlural = "%d Selecionados"
    }

    static let contentFilterMessageForSoundsiPhone = "Alguns sons não estão sendo exibidos pois a opção Exibir Conteúdo Sensível está desativada.\n\nVocê pode mudar isso nas Configurações (ícone de engrenagem no topo esquerdo da tela)."
    static let contentFilterMessageForSoundsiPadMac = "Alguns sons não estão sendo exibidos pois a opção Exibir Conteúdo Sensível está desativada.\n\nVocê pode mudar isso na tela de Configurações (ícone de engrenagem no topo da barra lateral do app)."
    static let contentFilterMessageForSongsiPhone = "Algumas músicas não estão sendo exibidas pois a opção Exibir Conteúdo Sensível está desativada.\n\nVocê pode mudar isso nas Configurações (ícone de engrenagem no topo da aba Sons)."
    static let contentFilterMessageForSongsiPadMac = "Algumas músicas não estão sendo exibidas pois a opção Exibir Conteúdo Sensível está desativada.\n\nVocê pode mudar isso na tela de Configurações (ícone de engrenagem no topo da barra lateral do app)."
    
    static func contentNotFoundAlertTitle(_ contentName: String) -> String {
        return "Conteúdo \"\(contentName)\" Indisponível"
    }
    static let contentNotFoundAlertMessage = "Devido a um problema técnico, o conteúdo que você quer acessar não está disponível."
    static let serverContentNotAvailableMessage = "Provavelmente houve um problema com o download desse conteúdo.\n\nPor favor, reporte esse erro para mim através do e-mail nas Configurações."
    static let serverContentNotAvailableRedownloadMessage = "Houve um problema com o download desse conteúdo."
    static let soundSharedSuccessfullyMessage = "Conteúdo compartilhado com sucesso."
    static let soundExportedSuccessfullyMessage = "Conteúdo exportado com sucesso."
    static let soundsExportedSuccessfullyMessage = "Conteúdos exportados com sucesso."
    static let songSharedSuccessfullyMessage = "Música compartilhada com sucesso."
    static let videoSharedSuccessfullyMessage = "Vídeo compartilhado com sucesso."
    
    static let unknownAuthor = "Desconhecido"
    
    struct Songs {
        
        static let songNotFoundAlertTitle = "Música Indisponível"
        static let songNotFoundAlertMessage = "Devido a um problema técnico, a música que você quer acessar não está disponível."
    }
    
    // E-mail
    
    static let issueSuggestionEmailSubject = "Problema/sugestão no app v\(Versioneer.appVersion) (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion))"
    static let issueSuggestionEmailBody = "Para um problema, inclua passos para reproduzir e prints se possível."
    static let suggestOtherAuthorNameEmailSubject = "Sugestão de Outro Nome de Autor Para %@"
    static let suggestOtherAuthorNameEmailBody = "Nome de autor antigo: %@\nNovo nome de autor: \n\nID do conteúdo: %@ (para uso interno)"
    
    struct Email {
        
        static let suggestSongChangeSubject = "Sugestão de Alteração Para a Música '%@'"
        static let suggestSongChangeBody = "\n\n\nID do conteúdo: %@ (para uso interno)"
        static let copyAddressSuccessMessage = "E-mail copiado com sucesso."

        struct AskForNewSound {
            
            static let subject = "Pedido de som de %@"
            static let body = "Inclua link para vídeo ou nome do episódio e minuto; qualquer dado que facilite o nosso trabalho."
        }
        
        struct AuthorDetailIssue {
            
            static let subject = "Problema com %@ no app v\(Versioneer.appVersion) (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion))"
            static let body = "Por favor, descreva o problema."
        }

        struct Reactions {
            static let suggestChangesSubject = "Sugerir Mudanças nas Reações v\(Versioneer.appVersion) (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion))"
            static let suggestChangesBody = "O que você gostaria de adicionar, remover ou mudar?"
        }
    }
    
    struct ShareAsVideo {
        
        static let generatingVideoShortMessage = "Gerando vídeo..."
        static let generatingVideoLongMessage = "Gerando vídeo...\nIsso pode demorar um pouco."
        static let videoSavedSucessfully = "Vídeo salvo com sucesso."
        static let videoSavedSucessfullyMac = "Vídeo salvo com sucesso no app Fotos."
    }
    
    struct Trends {
        
        static let last24Hours = "Últimas 24 horas"
        static let last3Days = "Últimos 3 dias"
        static let lastWeek = "Última semana"
        static let lastMonth = "Último mês"
        static let last3Months = "Últimos 3 meses"
        static let year2026 = "2026"
        static let year2025 = "2025"
        static let year2024 = "2024"
        static let year2023 = "2023"
        static let year2022 = "2022 (desde 21/06)"
        static let allTime = "Todos os tempos"
    }
    
    struct Folders {
        
        static let defaultFolderColor = "pastelPurple"
    }
    
    struct ScreenNames {

        static let authorsView = "AuthorsView"
        static let authorDetailView = "AuthorDetailView"
    }
    
    struct AuthorDetail {
        
        struct AskForNewSoundAlert {
            
            static let title = "Me Ajude a Te Ajudar"
            static let message = "Sou uma equipe de um homem só e poucos sons do podcast estão pré-cortados e separados.\n\nPara aumentar as chances do seu som ser incluído, coloque no e-mail o máximo de informações possível, como link para vídeo, nome do episódio e minuto no qual o som que você quer apareceu."
        }
    }

    struct Retro {

        static let successMessage = "Imagens salvas com sucesso. Compartilhe nas suas redes! ☺️"
    }

    struct Sync {

        static let waitMessage = "Atualizado recentemente. Aguarde %@."
    }

    struct BundleIds {

        static let applePhotosApp = "com.apple.mobileslideshow"
    }

    struct Search {

        static let searchPrompt = "Buscar conteúdo, autor ou pasta"
        static let episodeSearchPrompt = "Buscar título, descrição ou transcrição"

        struct Feedback {

            static let alertTitle = "Enviar Feedback"
            static let alertMessage = "Você será redirecionado para o app de e-mail padrão para enviar sua sugestão sobre a busca."
            static var emailSubject: String { "Feedback sobre a Busca Universal v\(Versioneer.appVersion)" }
            static let emailBody = "Conte-me o que você achou da nova busca e o que poderia melhorar:\n\n"
        }
    }
}
