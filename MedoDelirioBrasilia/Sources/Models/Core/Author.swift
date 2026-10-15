//
//  Author.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 20/05/22.
//

import Foundation

public struct Author: Hashable, Codable, Identifiable {

    public let id: String
    let name: String
    let photo: String?
    let description: String?
    var soundCount: Int?
    var externalLinks: String?
    /// Position in the row of favorite profile photos in Você, from 1. Nil when not in the
    /// row. Curated on the server, through MedoHelper.
    var featuredRank: Int?

    init(
        id: String,
        name: String,
        photo: String? = nil,
        description: String? = nil,
        soundCount: Int? = nil,
        externalLinks: String? = nil,
        featuredRank: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.photo = photo
        self.description = description
        self.soundCount = soundCount
        self.externalLinks = externalLinks
        self.featuredRank = featuredRank
    }

    var links: [ExternalLink] {
        guard let links = self.externalLinks else {
            return []
        }
        guard let jsonData = links.data(using: .utf8) else {
            return []
        }
        let decoder = JSONDecoder()
        do {
            let decodedLinks = try decoder.decode([ExternalLink].self, from: jsonData)
            return decodedLinks
        } catch {
            print("Error decoding JSON: \(error)")
            return []
        }
    }
}

extension Author {

    static let bozo = Author(
        id: UUID().uuidString,
        name: "Jair Bolsonaro",
        photo: "https://conteudo.imguol.com.br/c/noticias/3b/2024/04/18/o-ex-presidente-jair-bolsonaro-pl-em-evento-no-theatro-municipal-no-centro-de-sao-paulo-1713465239755_v2_900x506.jpg.webp"
    )

    static let omarAziz = Author(
        id: UUID().uuidString,
        name: "Omar Aziz",
        photo: "https://conteudo.imguol.com.br/c/noticias/a2/2019/09/18/06jul2019---o-senador-omar-aziz-apos-reuniao-na-residencia-oficial-da-presidencia-da-camara-com-rodrigo-maia-1568847478325_v2_1x1.jpg"
    )
}
