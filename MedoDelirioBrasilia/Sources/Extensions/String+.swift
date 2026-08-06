import SwiftUI

extension String {

    private static let htmlEntities: [(String, String)] = [
        ("&amp;", "&"),
        ("&lt;", "<"),
        ("&gt;", ">"),
        ("&quot;", "\""),
        ("&apos;", "'"),
        ("&#39;", "'"),
        ("&nbsp;", " "),
    ]

    /// Strips HTML tags, converts `<br>` variants to newlines, and decodes common HTML entities.
    func strippingHTML() -> String {
        var result = self
        // Normalise <br>, <br/>, <br /> to newlines
        result = result.replacingOccurrences(
            of: "<br\\s*/?>",
            with: "\n",
            options: .regularExpression
        )
        result = result.strippingTagsAndDecodingEntities()
        // Collapse multiple consecutive newlines into at most two
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips remaining HTML tags and decodes common HTML entities, without
    /// touching whitespace or newlines — used on individual segments where
    /// trimming would eat spacing intentionally left between them.
    func strippingTagsAndDecodingEntities() -> String {
        var result = self.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        for (entity, replacement) in Self.htmlEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }

    func withoutDiacritics() -> String {
        return self.folding(options: .diacriticInsensitive, locale: .current)
    }

    /// Normalizes a string for search by lowercasing, removing diacritics, stripping punctuation, and collapsing whitespace.
    func normalizedForSearch() -> String {
        return self
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func toPastelColor() -> Color {
        switch self {
        case "pastelPurple":
            return .pastelPurple
        case "pastelBabyBlue":
            return .pastelBabyBlue
        case "pastelBrightGreen":
            return .pastelBrightGreen
        case "pastelYellow":
            return .pastelYellow
        case "pastelOrange":
            return .pastelOrange
        case "pastelPink":
            return .pastelPink
        case "pastelGray":
            return .pastelGray
        case "pastelRoyalBlue":
            return .pastelRoyalBlue
        case "pastelMutedGreen":
            return .pastelMutedGreen
        case "pastelRed":
            return .pastelRed
        case "pastelBeige":
            return .pastelBeige
        default:
            return .white
        }
    }
}

extension String {

    var formattedDate: String {
        if let date = Formatter.apiDateInput.date(from: self) {
            return Formatter.apiDateOutput.string(from: date)
        } else {
            return "Formato de data inválido"
        }
    }
}

extension String {

    func timeUntil(addingMinutes minutes: Int) -> String {
        guard let date = self.iso8601withFractionalSeconds else { return "" }
        let twoMinutesFromLastUpdate = Calendar.current.date(byAdding: .minute, value: minutes, to: date)

        guard let endDate = twoMinutesFromLastUpdate else { return "" }
        let components = Calendar.current.dateComponents([.minute, .second], from: .now, to: endDate)

        guard let minutes = components.minute, let seconds = components.second else { return "" }
        if minutes > 0 {
            return "\(minutes) minuto e \(seconds) segundos"
        } else {
            return seconds > 1 ? "\(seconds) segundos" : "1 segundo"
        }
    }
}

extension String {

    func toColor() -> Color {
        switch self {
        case "red":
            return .red
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        case "black":
            return .black
        case "blue":
            return .blue
        case "brown":
            return .brown
        case "gray":
            return .gray
        case "green":
            return .green
        case "purple":
            return .purple
        case "pink":
            return .pink
        case "mint":
            return .mint
        case "teal":
            return .teal
        case "cyan":
            return .cyan
        case "indigo":
            return .indigo
        default:
            return .white
        }
    }
}
