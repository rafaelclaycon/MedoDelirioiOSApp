//
//  Episode+Mocks.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/11/24.
//

import Foundation

extension Episode {

    static var mock: Self {
        .init(
            episodeId: "abcdefgh3876",
            title: "II - Dias 690 a 696 | \"Tão deixando a gente sonhar\" | 16 a 22/11/24",
            description: "Sobre golpes e generais enjaulados.\n\nBLACK FRAUDE NO MEDO E DELÍRIO!!!\n\n15% de desconto com o cupom MEDOEDELIRIO\n\nMUITAS ESTAMPAS NOVAS! Agora tamanhos infantis!\n\nVai lá que a promoção vai até 08/12 só!\n\nloja.medoedelirioembrasilia.com.br\n\nThe post II – Dias 690 a 696 | “Tão deixando a gente sonhar” | 16 a 22/11/24 appeared first on Central 3.",
            pubDate: .now,
            duration: 300,
            creationDate: .now
        )
    }
}
