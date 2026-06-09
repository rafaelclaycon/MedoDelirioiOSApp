//
//  Double+Extensions.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 06/02/23.
//

import Foundation

extension Double {

    /// String version of a Double formatted as `mm:ss`.
    var minuteSecondFormatted: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? ""
    }

    /// A version of `mm:ss` formatting that shows `< 1 s` for any time below 1 second.
    var minuteSecondFormattedPretty: String {
        guard self >= 1.0 else {
            return "< 1 s"
        }
        return self.minuteSecondFormatted
    }
}
