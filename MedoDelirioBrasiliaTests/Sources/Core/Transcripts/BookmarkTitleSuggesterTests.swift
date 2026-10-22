//
//  BookmarkTitleSuggesterTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 22/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct BookmarkTitleSuggesterTests {

    private let cues: [SRTCue] = [
        SRTCue(index: 1, startTime: 10, endTime: 14, text: "Boa noite, boa noite."),
        SRTCue(index: 2, startTime: 14, endTime: 18, text: "Hoje o assunto é sério."),
        SRTCue(index: 3, startTime: 30, endTime: 34, text: "Depois da pausa."),
    ]

    // MARK: - Picking the line

    @Test
    func title_duringALine_shouldUseThatLine() {
        #expect(BookmarkTitleSuggester.title(from: cues, at: 15) == "Hoje o assunto é sério.")
    }

    @Test
    func title_atTheBoundary_shouldUseTheLineStarting() {
        #expect(BookmarkTitleSuggester.title(from: cues, at: 14) == "Hoje o assunto é sério.")
    }

    @Test
    func title_inAShortPause_shouldUseTheLineJustSaid() {
        #expect(BookmarkTitleSuggester.title(from: cues, at: 21) == "Hoje o assunto é sério.")
    }

    @Test
    func title_inALongPause_shouldBeNil() {
        #expect(BookmarkTitleSuggester.title(from: cues, at: 25) == nil)
    }

    @Test
    func title_beforeTheFirstLine_shouldBeNil() {
        #expect(BookmarkTitleSuggester.title(from: cues, at: 5) == nil)
    }

    @Test
    func title_withNoCues_shouldBeNil() {
        #expect(BookmarkTitleSuggester.title(from: [], at: 15) == nil)
    }

    // MARK: - Shortening

    @Test
    func shortened_withShortLine_shouldKeepItWhole() {
        #expect(BookmarkTitleSuggester.shortened("Deixa cada um se fuder!") == "Deixa cada um se fuder!")
    }

    @Test
    func shortened_withLineBreaks_shouldJoinIntoOneLine() {
        #expect(BookmarkTitleSuggester.shortened("Mas aí vai depender\nda   vontade dele.") == "Mas aí vai depender da vontade dele.")
    }

    @Test
    func shortened_withLongLine_shouldCutAtAWordAndAddEllipsis() {
        let text = "Nosso plano, a gente vai arrumar as contas do Brasil, organizar, fortalecer a gestão das estatais,"

        let result = BookmarkTitleSuggester.shortened(text)

        #expect(result == "Nosso plano, a gente vai arrumar as contas do Brasil…")
        #expect((result?.count ?? 0) <= BookmarkTitleSuggester.maxLength + 1)
    }

    @Test
    func shortened_withLineEndingInComma_shouldEndInEllipsis() {
        #expect(BookmarkTitleSuggester.shortened("estancar esse buraco, enxugar a estrutura,") == "estancar esse buraco, enxugar a estrutura…")
    }

    @Test
    func shortened_withCutAtSentenceEnd_shouldNotAddEllipsis() {
        let text = "Isso aqui é uma frase que termina exatamente em cinquenta. E continua depois."

        #expect(BookmarkTitleSuggester.shortened(text) == "Isso aqui é uma frase que termina exatamente em cinquenta.")
    }

    @Test
    func shortened_withOneLongWord_shouldHardCut() {
        let text = String(repeating: "a", count: 80)

        #expect(BookmarkTitleSuggester.shortened(text) == String(repeating: "a", count: 60) + "…")
    }

    @Test
    func shortened_withOnlyWhitespace_shouldBeNil() {
        #expect(BookmarkTitleSuggester.shortened("  \n ") == nil)
    }
}
