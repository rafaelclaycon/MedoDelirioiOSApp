//
//  Double+Extensions.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 06/02/23.
//

import Foundation

extension Double {

    var minuteSecondFormatted: String {
        guard self >= 1.0 else {
            return "< 1 s"
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? ""
    }
}
