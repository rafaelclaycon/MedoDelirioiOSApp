//
//  TopHit.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 07/04/26.
//

import Foundation

enum TopHitItem {
    case sound(AnyEquatableMedoContent)
    case song(AnyEquatableMedoContent)
    case author(Author)
    case folder(UserFolder)
    case reaction(Reaction)
}

struct TopHit: Identifiable {
    let id: String
    let item: TopHitItem
    let weightedScore: Double
}
