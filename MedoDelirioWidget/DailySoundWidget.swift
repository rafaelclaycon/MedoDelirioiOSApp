import SwiftUI
import WidgetKit

// MARK: - Shared cache model (mirrors WidgetSoundCacheEntry in the main app)

struct WidgetSoundCacheEntry: Codable {
    let id: String
    let title: String
    let authorName: String
    let description: String
}

enum WidgetSoundCache {

    static func read() -> [WidgetSoundCacheEntry] {
        guard
            let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.rafaelschmitt.MedoDelirioBrasilia")?
                .appendingPathComponent("widget_sound_cache.json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([WidgetSoundCacheEntry].self, from: data)
        else { return [] }
        return entries
    }
}

// MARK: - Timeline

struct DailySoundEntry: TimelineEntry {
    let date: Date
    let sound: WidgetSoundCacheEntry?
}

struct DailySoundProvider: TimelineProvider {

    func placeholder(in context: Context) -> DailySoundEntry {
        DailySoundEntry(date: .now, sound: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailySoundEntry) -> Void) {
        completion(DailySoundEntry(date: .now, sound: todaySound()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailySoundEntry>) -> Void) {
        let entry = DailySoundEntry(date: .now, sound: todaySound())
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func todaySound() -> WidgetSoundCacheEntry? {
        let sounds = WidgetSoundCache.read()
        guard !sounds.isEmpty else { return nil }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        let seed = (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
        return sounds[abs(seed) % sounds.count]
    }
}

// MARK: - View

struct DailySoundWidgetView: View {

    let entry: DailySoundEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let sound = entry.sound {
            VStack(alignment: .leading, spacing: 4) {
                Text("Som do dia")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text(displayText(for: sound))
                    .font(family == .systemSmall ? .callout : .body)
                    .fontWeight(.medium)
                    .lineLimit(family == .systemSmall ? 4 : 6)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                Text("— \(sound.authorName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(URL(string: "medodelirio://sound/\(sound.id)"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "speaker.wave.2")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Abra o app para\ncarregar o som do dia")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func displayText(for sound: WidgetSoundCacheEntry) -> String {
        sound.description.isEmpty ? sound.title : sound.description
    }
}

// MARK: - Preview

#Preview("Small – with sound", as: .systemSmall) {
    DailySoundWidget()
} timeline: {
    DailySoundEntry(
        date: .now,
        sound: WidgetSoundCacheEntry(
            id: "preview-1",
            title: "Lula - Eu posso tomar café",
            authorName: "Lula",
            description: "Eu posso tomar café, eu posso tomar café, isso eu posso."
        )
    )
}

#Preview("Medium – with sound", as: .systemMedium) {
    DailySoundWidget()
} timeline: {
    DailySoundEntry(
        date: .now,
        sound: WidgetSoundCacheEntry(
            id: "preview-2",
            title: "Cadê os machos?",
            authorName: "Michelle Bolsonaro",
            description: "Cadê os machos dessa terra que não aparecem pra defender o presidente?"
        )
    )
}

#Preview("Small – empty cache", as: .systemSmall) {
    DailySoundWidget()
} timeline: {
    DailySoundEntry(date: .now, sound: nil)
}

// MARK: - Widget

struct DailySoundWidget: Widget {

    let kind = "com.rafaelschmitt.MedoDelirioBrasilia.DailySoundWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailySoundProvider()) { entry in
            DailySoundWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Som do Dia")
        .description("Um som diferente do Medo e Delírio todo dia.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
