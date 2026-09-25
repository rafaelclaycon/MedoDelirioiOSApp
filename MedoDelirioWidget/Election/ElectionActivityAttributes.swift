//
//  ElectionActivityAttributes.swift
//  MedoDelirioWidget
//
//  Created by Rafael Schmitt on 24/09/26.
//

import ActivityKit
import Foundation

/// Shared between the app (starts the activity) and the widget extension (renders it).
///
/// `ContentState` arrives two ways: from `v4/election/live` when the activity starts, and
/// from APNs broadcast pushes afterwards, which ActivityKit decodes with a plain `JSONDecoder`.
/// To keep one wire format for both, it uses camelCase keys and no `Date` (a plain decoder
/// expects seconds since 2001, the app's API client expects ISO 8601).
struct ElectionActivityAttributes: ActivityAttributes {

    /// 1 or 2.
    let round: Int

    struct ContentState: Codable, Hashable {
        var sectionsCountedPercent: Double
        var isFinal: Bool
        /// TSE totalization time, seconds since 1970.
        var updatedAt: Double
        /// Already trimmed and ordered by the server.
        var candidates: [Candidate]

        var leader: Candidate? {
            candidates.first
        }

        var updatedAtDate: Date {
            Date(timeIntervalSince1970: updatedAt)
        }
    }

    struct Candidate: Codable, Hashable, Identifiable {
        let number: Int
        let name: String
        let party: String
        let percent: Double
        let status: Status
        /// "#RRGGBB". Sent by the server so a candidate keeps their color when positions swap.
        let colorHex: String?

        var id: Int { number }
    }

    enum Status: String, Codable {
        case counting
        case elected
        case runoff
        case notElected
    }
}
