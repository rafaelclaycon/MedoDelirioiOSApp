import Foundation

extension APIClient {

    func subscribeToChannel(_ channelId: String) async throws {
        let url = URL(string: serverPath + "v4/subscribe-channel")!
        let body = ChannelSubscription(
            installId: AppPersistentMemory.shared.customInstallId,
            channelId: channelId
        )
        try await performChannelRequest(method: "POST", url: url, body: body)
    }

    func unsubscribeFromChannel(_ channelId: String) async throws {
        let url = URL(string: serverPath + "v4/unsubscribe-channel")!
        let body = ChannelSubscription(
            installId: AppPersistentMemory.shared.customInstallId,
            channelId: channelId
        )
        try await performChannelRequest(method: "POST", url: url, body: body)
    }

    func deviceChannels() async throws -> [String] {
        let installId = AppPersistentMemory.shared.customInstallId
        let url = URL(string: serverPath + "v4/device-channels/\(installId)")!

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let responseBody = String(data: data, encoding: .utf8)
            let success = statusCode == 200

            if statusCode == 404 {
                ChannelLogStore.shared.logEvent(
                    "Dispositivo não encontrado (404)",
                    success: true
                )
                return []
            }

            ChannelLogStore.shared.log(
                method: "GET",
                url: url.absoluteString,
                statusCode: statusCode,
                responseBody: responseBody,
                success: success,
                errorMessage: success ? nil : "HTTP \(statusCode ?? 0)"
            )

            guard success else {
                throw APIClientError.unexpectedStatusCode
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([String].self, from: data)
        } catch let error where !(error is APIClientError) {
            ChannelLogStore.shared.log(
                method: "GET",
                url: url.absoluteString,
                success: false,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }

    // MARK: - Channel Helpers

    private func performChannelRequest<T: Encodable>(method: String, url: URL, body: T) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        let requestData = try encoder.encode(body)
        request.httpBody = requestData

        let requestBodyString = String(data: requestData, encoding: .utf8) ?? "<encoding failed>"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let responseBody = String(data: data, encoding: .utf8)
            let success = statusCode == 200

            ChannelLogStore.shared.log(
                method: method,
                url: url.absoluteString,
                requestBody: requestBodyString,
                statusCode: statusCode,
                responseBody: responseBody,
                success: success,
                errorMessage: success ? nil : "HTTP \(statusCode ?? 0)"
            )

            guard success else {
                throw APIClientError.unexpectedStatusCode
            }
        } catch let error where !(error is APIClientError) {
            ChannelLogStore.shared.log(
                method: method,
                url: url.absoluteString,
                requestBody: requestBodyString,
                success: false,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }
}
