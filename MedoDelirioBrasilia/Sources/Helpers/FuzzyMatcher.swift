//
//  FuzzyMatcher.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 07/04/26.
//

import Foundation

struct ScoredItem<T> {
    let item: T
    let score: Double
}

enum SearchField {

    case title
    case authorName
    case description
    case folderName
    case reactionTitle

    var weight: Double {
        switch self {
        case .title:         return 3.0
        case .authorName:    return 2.0
        case .description:   return 1.5
        case .folderName:    return 1.5
        case .reactionTitle: return 1.5
        }
    }
}

enum FuzzyMatcher {

    static let minimumScoreThreshold: Double = 0.3

    /// Scores how well `query` matches `candidate`. Returns 0.0 (no match) to 1.0 (perfect).
    static func score(query: String, against candidate: String) -> Double {
        let normalizedQuery = query.normalizedForSearch()
        let normalizedCandidate = candidate.normalizedForSearch()

        guard !normalizedQuery.isEmpty, !normalizedCandidate.isEmpty else { return 0.0 }

        if normalizedCandidate.contains(normalizedQuery) {
            return 1.0
        }

        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        let candidateTokens = normalizedCandidate.split(separator: " ").map(String.init)

        guard !queryTokens.isEmpty, !candidateTokens.isEmpty else { return 0.0 }

        var totalScore = 0.0

        for qToken in queryTokens {
            var bestTokenScore = 0.0

            for cToken in candidateTokens {
                if cToken.hasPrefix(qToken) {
                    bestTokenScore = max(bestTokenScore, 0.8)
                    continue
                }

                if qToken.hasPrefix(cToken) {
                    let ratio = Double(cToken.count) / Double(qToken.count)
                    bestTokenScore = max(bestTokenScore, ratio * 0.7)
                    continue
                }

                let distance = levenshtein(qToken, cToken)
                let maxLen = max(qToken.count, cToken.count)
                let threshold = maxLen <= 3 ? 1 : 2

                if distance <= threshold {
                    let similarity = 1.0 - (Double(distance) / Double(maxLen))
                    bestTokenScore = max(bestTokenScore, similarity * 0.6)
                }
            }

            totalScore += bestTokenScore
        }

        return totalScore / Double(queryTokens.count)
    }

    /// Standard dynamic-programming Levenshtein edit distance.
    static func levenshtein(_ source: String, _ target: String) -> Int {
        let s = Array(source)
        let t = Array(target)
        let sCount = s.count
        let tCount = t.count

        if sCount == 0 { return tCount }
        if tCount == 0 { return sCount }

        var previousRow = Array(0...tCount)
        var currentRow = [Int](repeating: 0, count: tCount + 1)

        for i in 1...sCount {
            currentRow[0] = i
            for j in 1...tCount {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + cost
                )
            }
            swap(&previousRow, &currentRow)
        }

        return previousRow[tCount]
    }
}
