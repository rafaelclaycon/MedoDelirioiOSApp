import Foundation

struct WidgetSoundCacheEntry: Codable {
    let id: String
    let title: String
    let authorName: String
    let description: String
}

enum WidgetSoundCache {

    static let appGroupIdentifier = "group.com.rafaelschmitt.MedoDelirioBrasilia"

    private static var cacheURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("widget_sound_cache.json")
    }

    static func write(_ entries: [WidgetSoundCacheEntry]) {
        guard let url = cacheURL else { return }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read() -> [WidgetSoundCacheEntry] {
        guard
            let url = cacheURL,
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([WidgetSoundCacheEntry].self, from: data)
        else { return [] }
        return entries
    }
}
