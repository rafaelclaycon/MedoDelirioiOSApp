//
//  TimeInterval+.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/08/26.
//

import Foundation

extension TimeInterval {

    /// A playback position formatted as `M:SS`, or `H:MM:SS` once past an hour.
    ///
    /// Negative values clamp to zero — callers routinely derive positions by
    /// subtraction (`duration - currentTime`) and can land slightly below zero
    /// on the final tick.
    var asPlaybackTime: String {
        let totalSeconds = max(Int(self), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
