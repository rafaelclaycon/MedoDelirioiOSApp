//
//  APIClient+Generic.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 04/05/23.
//

import Foundation

extension APIClient {

    func `get`<T: Codable>(from url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let response = response as? HTTPURLResponse else {
            throw APIClientError.responseWasNotAnHTTPURLResponse
        }
        if response.statusCode == 404 {
            throw APIClientError.resourceNotFound
        }
        guard response.statusCode == 200 else {
            print(response.statusCode)
            throw APIClientError.unexpectedStatusCode
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(T.self, from: data)
    }

    func post<T: Codable, U: Encodable>(to url: URL, body: U) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.responseWasNotAnHTTPURLResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIClientError.unexpectedStatusCode
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }

    func post<T: Encodable>(to url: URL, body: T) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.responseWasNotAnHTTPURLResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIClientError.unexpectedStatusCode
        }
    }
}
