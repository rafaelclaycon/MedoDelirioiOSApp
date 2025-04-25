//
//  Double+ToDisplayString.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/10/22.
//

import Foundation

extension Double {

    func toDisplayString() -> String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60

        // Less than a minute
        if totalSeconds < 60 {
            return String(format: "%1ds", seconds)
            // Less than an hour
        } else if totalSeconds < 3600 {
            // If "whole" minutes
            if (totalSeconds % 60) < 60 {
                return String(format: "%1dm", minutes)
            } else {
                return String(format: "%1dm %1ds", minutes, seconds)
            }
        } else {
            // If "whole" hours
            if (totalSeconds % 3600) < 60 {
                return String(format: "%1dh", hours)
            } else {
                return String(format: "%1dh %1dm", hours, minutes)
            }
        }
    }

}
