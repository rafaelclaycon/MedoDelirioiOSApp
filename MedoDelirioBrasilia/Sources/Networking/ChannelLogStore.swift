import Foundation

struct ChannelLogEntry: Identifiable, Codable {

    let id: UUID
    let timestamp: Date
    let method: String
    let url: String
    let requestBody: String?
    let statusCode: Int?
    let responseBody: String?
    let success: Bool
    let errorMessage: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        method: String,
        url: String,
        requestBody: String? = nil,
        statusCode: Int? = nil,
        responseBody: String? = nil,
        success: Bool,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.url = url
        self.requestBody = requestBody
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.success = success
        self.errorMessage = errorMessage
    }
}

@Observable
final class ChannelLogStore {

    static let shared = ChannelLogStore()

    private static let maxEntries = 200

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("push_logs.json")
    }

    private(set) var entries: [ChannelLogEntry] = []

    private init() {
        entries = Self.loadFromDisk()
    }

    func log(
        method: String,
        url: String,
        requestBody: String? = nil,
        statusCode: Int? = nil,
        responseBody: String? = nil,
        success: Bool,
        errorMessage: String? = nil
    ) {
        let entry = ChannelLogEntry(
            method: method,
            url: url,
            requestBody: requestBody,
            statusCode: statusCode,
            responseBody: responseBody,
            success: success,
            errorMessage: errorMessage
        )
        Task { @MainActor in
            self.append(entry)
        }
    }

    func logEvent(
        _ description: String,
        success: Bool,
        errorMessage: String? = nil
    ) {
        let entry = ChannelLogEntry(
            method: description,
            url: "",
            success: success,
            errorMessage: errorMessage
        )
        Task { @MainActor in
            self.append(entry)
        }
    }

    // MARK: - Private

    @MainActor
    private func append(_ entry: ChannelLogEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        saveToDisk()
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            print("Failed to save push logs: \(error.localizedDescription)")
        }
    }

    private static func loadFromDisk() -> [ChannelLogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ChannelLogEntry].self, from: data)
        } catch {
            print("Failed to load push logs: \(error.localizedDescription)")
            return []
        }
    }
}
