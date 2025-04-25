//
//  DateTime+AsShortString.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/10/22.
//

import Foundation

extension Date {

    // Possibilities for dateStyle: .short, .medium, .long, .full
    func asShortString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.dateStyle = .short
        return dateFormatter.string(from: self)
    }

    func asLongString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.dateStyle = .long
        return dateFormatter.string(from: self)
    }
}
