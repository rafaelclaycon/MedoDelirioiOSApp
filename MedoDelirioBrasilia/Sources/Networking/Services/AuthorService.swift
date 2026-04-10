//
//  AuthorService.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/04/25.
//

import Foundation

protocol AuthorServiceProtocol {

    func allAuthors(_ sortOrder: AuthorSortOption) throws -> [Author]

    func authors(matchingName name: String) -> [Author]?
    func authors(fuzzyMatchingName name: String) -> [ScoredItem<Author>]?
}

final class AuthorService: AuthorServiceProtocol {

    private let database: LocalDatabaseProtocol

    private var allAuthors: [Author]?

    // MARK: - Initializer

    init(
        database: LocalDatabaseProtocol
    ) {
        self.database = database
        self.allAuthors = []
        loadAllAuthors()
    }

    // MARK: - Functions

    func allAuthors(_ sortOrder: AuthorSortOption) throws -> [Author] {
        guard let allAuthors, allAuthors.count > 0 else { return [] }
        return sort(authors: allAuthors, by: sortOrder)
    }

    func authors(matchingName name: String) -> [Author]? {
        guard !name.isEmpty else { return nil }
        guard let allAuthors, allAuthors.count > 0 else { return nil }
        let normalizedSearch = name.normalizedForSearch()
        let copy = allAuthors.filter { $0.name.normalizedForSearch().contains(normalizedSearch) }
        let authors = sort(authors: copy, by: .nameAscending)
        return authors.isEmpty ? nil : authors
    }

    func authors(fuzzyMatchingName name: String) -> [ScoredItem<Author>]? {
        guard !name.isEmpty else { return nil }
        guard let allAuthors, allAuthors.count > 0 else { return nil }
        let scored = allAuthors
            .compactMap { author -> ScoredItem<Author>? in
                let score = FuzzyMatcher.score(query: name, against: author.name)
                guard score >= FuzzyMatcher.minimumScoreThreshold else { return nil }
                return ScoredItem(item: author, score: score)
            }
            .sorted { $0.score > $1.score }
        return scored.isEmpty ? nil : scored
    }
}

// MARK: - Internal Functions

extension AuthorService {

    private func loadAllAuthors() {
        do {
            allAuthors = try database.allAuthors()
        } catch {
            debugPrint(error)
        }
    }

    private func sort(authors: [Author], by sortOption: AuthorSortOption) -> [Author] {
        switch sortOption {
        case .nameAscending:
            authors.sorted(by: { $0.name.withoutDiacritics() < $1.name.withoutDiacritics() })
        case .soundCountDescending:
            authors.sorted(by: { $0.soundCount ?? 0 > $1.soundCount ?? 0 })
        case .soundCountAscending:
            authors.sorted(by: { $0.soundCount ?? 0 < $1.soundCount ?? 0 })
        case .descriptionLengthDescending:
            authors.sorted(by: { ($0.description?.count ?? 0) > ($1.description?.count ?? 0) })
        }
    }
}
