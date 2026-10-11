//
//  APIClient.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 08/06/22.
//

import Foundation

internal protocol APIClientProtocol {

    var serverPath: String { get }

    func sound(_ id: String) async throws -> Sound
    func song(_ id: String) async throws -> Song
    func author(_ id: String) async throws -> Author
    func musicGenre(_ id: String) async throws -> MusicGenre

    func `get`<T: Codable>(from url: URL) async throws -> T
    func getString(from url: URL) async throws -> String?

    func serverIsAvailable() async -> Bool
    func post(shareCountStat: ServerShareCountStat) async throws
    func post(clientDeviceInfo: ClientDeviceInfo) async throws
    func fetchUpdateEvents(from lastDate: String) async throws -> [UpdateEvent]

    func displayAskForMoneyView(appVersion: String) async -> Bool
    func getDonorNames() async -> [Donor]?
    func moneyInfo() async throws -> [MoneyInfo]

    func post<T: Encodable>(to url: URL, body: T) async throws

    func top3Reactions() async throws -> [Reaction]
    func getReactionsStats() async throws -> [TopChartReaction]
    func getShareCountStats(
        for contentType: TrendsContentType,
        in timeInterval: TrendsTimeInterval
    ) async throws -> [TopChartItem]
    func getPlayCountStats(
        for contentType: TrendsContentType,
        in timeInterval: TrendsTimeInterval
    ) async throws -> [TopPlayedItem]
    func getEpisodePlayStats(
        in timeInterval: TrendsTimeInterval
    ) async throws -> [TopEpisodeItem]
}

class APIClient: APIClientProtocol {

    let serverPath: String

    // APIClient(serverPath: "https://654e-2804-1b3-8640-96df-d0b4-dd5d-6922-bb1b.sa.ngrok.io/api/")
    static let shared = APIClient(
        serverPath: APIConfig.apiURL
    )

    init(serverPath: String) {
        self.serverPath = serverPath
    }

    // MARK: - GET

    func serverIsAvailable() async -> Bool {
        let url = URL(string: serverPath + "v2/status-check")!
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            print("Erro ao verificar conexão com o servidor: \(error)")
            return false
        }
    }

    func getString(from url: URL) async throws -> String? {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let response = response as? HTTPURLResponse else {
            throw APIClientError.responseWasNotAnHTTPURLResponse
        }
        if response.statusCode == 404 {
            throw APIClientError.resourceNotFound
        }
        guard response.statusCode == 200 else {
            throw APIClientError.unexpectedStatusCode
        }
        return String(data: data, encoding: .utf8)
    }

    func sound(_ id: String) async throws -> Sound {
        guard let url = URL(string: serverPath + "v3/sound/\(id)") else {
            throw APIClientError.unableToCreateUrlFor(id)
        }
        return try await get(from: url)
    }

    func song(_ id: String) async throws -> Song {
        guard let url = URL(string: serverPath + "v3/song/\(id)") else {
            throw APIClientError.unableToCreateUrlFor(id)
        }
        return try await get(from: url)
    }

    func author(_ id: String) async throws -> Author {
        guard let url = URL(string: serverPath + "v3/author/\(id)") else {
            throw APIClientError.unableToCreateUrlFor(id)
        }
        return try await get(from: url)
    }

    func musicGenre(_ id: String) async throws -> MusicGenre {
        guard let url = URL(string: serverPath + "v3/music-genre/\(id)") else {
            throw APIClientError.unableToCreateUrlFor(id)
        }
        return try await get(from: url)
    }

    // MARK: - POST

    func post(shareCountStat: ServerShareCountStat) async throws {
        let url = URL(string: serverPath + "v1/share-count-stat")!
        try await post(to: url, body: shareCountStat)
    }

    func post(clientDeviceInfo: ClientDeviceInfo) async throws {
        let url = URL(string: serverPath + "v1/client-device-info")!
        try await post(to: url, body: clientDeviceInfo)
    }
}

// MARK: - Errors

enum APIClientError: Error, LocalizedError {

    case unexpectedStatusCode
    case responseWasNotAnHTTPURLResponse
    case invalidResponse
    case httpRequestFailed
    case errorFetchingUpdateEvents(String)
    case resourceNotFound
    case unableToCreateUrlFor(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatusCode:
            return "O servidor respondeu com um código de status inesperado."
        case .responseWasNotAnHTTPURLResponse:
            return "A resposta da rede não foi uma resposta HTTP URL."
        case .invalidResponse:
            return "A resposta do servidor é inválida ou está corrompida."
        case .httpRequestFailed:
            return "A requisição HTTP falhou devido a um erro de rede ou servidor."
        case .errorFetchingUpdateEvents(let errorMessage):
            return "Erro ao obter UpdateEvents: \(errorMessage)"
        case .resourceNotFound:
            return "Recurso não encontrado."
        case .unableToCreateUrlFor(let id):
            return "Não foi possível criar URL para \(id)."
        }
    }
}
