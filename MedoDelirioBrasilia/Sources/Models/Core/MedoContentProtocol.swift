//
//  MedoContentProtocol.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 15/09/23.
//

import Foundation
import SwiftUI

internal protocol MedoContentProtocol: Equatable {

    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var description: String { get }
    var duration: Double { get }
    var dateAdded: Date? { get set }
    var isFromServer: Bool? { get }
    var type: MediaType { get }
    var authorId: String { get }
    var isOffensive: Bool { get }
    var primaryColor: Color { get }

    func fileURL() throws -> URL
}

extension MedoContentProtocol {

    /// Derives a display color from the content's `authorId`.
    /// - Note: Temporary stand-in until the server exposes a `color` field on Author.
    ///         Replace this with the decoded server value when that field ships.
    var primaryColor: Color {
        let palette: [Color] = [
            .red, .orange, .yellow, .green,
            .teal, .blue, .purple, .brown,
            .pink, .cyan, .indigo, .mint, .gray
        ]
        let hash = subtitle.unicodeScalars.reduce(0 as UInt) { $0 &+ UInt($1.value) }
        return palette[Int(hash % UInt(palette.count))]
    }
}
