//
//  FuzzyMatcherTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 07/04/26.
//

import Testing
@testable import MedoDelirio

struct FuzzyMatcherTests {

    // MARK: - Exact Match

    @Test("Exact substring match returns 1.0")
    func test_exactSubstringMatch() {
        let score = FuzzyMatcher.score(query: "Bolsonaro", against: "Jair Bolsonaro")
        #expect(score == 1.0)
    }

    @Test("Identical strings return 1.0")
    func test_identicalStrings() {
        let score = FuzzyMatcher.score(query: "Dilma", against: "Dilma")
        #expect(score == 1.0)
    }

    // MARK: - Prefix Match

    @Test("Prefix match returns high score")
    func test_prefixMatch() {
        let score = FuzzyMatcher.score(query: "Bol", against: "Bolsonaro")
        #expect(score >= 0.7)
    }

    @Test("Multi-token prefix match scores well")
    func test_multiTokenPrefixMatch() {
        let score = FuzzyMatcher.score(query: "Jair Bol", against: "Jair Bolsonaro")
        #expect(score >= 0.7)
    }

    // MARK: - Fuzzy / Typo Tolerance

    @Test("Single-character typo still matches above threshold")
    func test_singleCharTypo() {
        let score = FuzzyMatcher.score(query: "Bolsanaro", against: "Bolsonaro")
        #expect(score >= FuzzyMatcher.minimumScoreThreshold)
    }

    @Test("Close misspelling scores above threshold")
    func test_closeMisspelling() {
        let score = FuzzyMatcher.score(query: "Dilam", against: "Dilma")
        #expect(score >= FuzzyMatcher.minimumScoreThreshold)
    }

    // MARK: - No Match

    @Test("Completely unrelated strings return 0.0")
    func test_noMatch() {
        let score = FuzzyMatcher.score(query: "Xylophone", against: "Bolsonaro")
        #expect(score < FuzzyMatcher.minimumScoreThreshold)
    }

    @Test("Empty query returns 0.0")
    func test_emptyQuery() {
        let score = FuzzyMatcher.score(query: "", against: "Bolsonaro")
        #expect(score == 0.0)
    }

    @Test("Empty candidate returns 0.0")
    func test_emptyCandidate() {
        let score = FuzzyMatcher.score(query: "Bolsonaro", against: "")
        #expect(score == 0.0)
    }

    // MARK: - Diacritics

    @Test("Diacritics are normalized before matching")
    func test_diacriticsNormalized() {
        let score = FuzzyMatcher.score(query: "virgula", against: "Vírgula")
        #expect(score == 1.0)
    }

    // MARK: - Levenshtein

    @Test("Levenshtein of identical strings is 0")
    func test_levenshtein_identical() {
        #expect(FuzzyMatcher.levenshtein("abc", "abc") == 0)
    }

    @Test("Levenshtein of empty vs non-empty")
    func test_levenshtein_emptyVsNonEmpty() {
        #expect(FuzzyMatcher.levenshtein("", "abc") == 3)
        #expect(FuzzyMatcher.levenshtein("abc", "") == 3)
    }

    @Test("Levenshtein of single substitution")
    func test_levenshtein_singleSubstitution() {
        #expect(FuzzyMatcher.levenshtein("cat", "car") == 1)
    }

    @Test("Levenshtein of insertion")
    func test_levenshtein_insertion() {
        #expect(FuzzyMatcher.levenshtein("cat", "cats") == 1)
    }

    @Test("Levenshtein of deletion")
    func test_levenshtein_deletion() {
        #expect(FuzzyMatcher.levenshtein("cats", "cat") == 1)
    }

    @Test("Levenshtein of transposition-like change")
    func test_levenshtein_transposition() {
        #expect(FuzzyMatcher.levenshtein("ab", "ba") == 2)
    }

    // MARK: - Score Ordering

    @Test("Exact match scores higher than prefix match")
    func test_exactScoresHigherThanPrefix() {
        let exact = FuzzyMatcher.score(query: "Dilma", against: "Dilma Rousseff")
        let prefix = FuzzyMatcher.score(query: "Dilma", against: "Dil")
        #expect(exact > prefix)
    }

    @Test("Prefix match scores higher than fuzzy match")
    func test_prefixScoresHigherThanFuzzy() {
        let prefix = FuzzyMatcher.score(query: "Bolso", against: "Bolsonaro")
        let fuzzy = FuzzyMatcher.score(query: "Bolsanaro", against: "Bolsonaro")
        #expect(prefix > fuzzy)
    }
}
