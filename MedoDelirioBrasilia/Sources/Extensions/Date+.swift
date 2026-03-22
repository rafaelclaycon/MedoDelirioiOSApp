//
//  Date+.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 20/06/22.
//

import Foundation

private enum ThreadLocalFormatterCache {
    static func formatter<T: NSObject>(forKey key: String, create: () -> T) -> T {
        if let cached = Thread.current.threadDictionary[key] as? T {
            return cached
        }

        let formatter = create()
        Thread.current.threadDictionary[key] = formatter
        return formatter
    }
}

extension ISO8601DateFormatter {
    convenience init(_ formatOptions: Options) {
        self.init()
        self.formatOptions = formatOptions
    }
}

extension Formatter {
    static var iso8601withFractionalSeconds: ISO8601DateFormatter {
        ThreadLocalFormatterCache.formatter(forKey: "iso8601withFractionalSeconds") {
            ISO8601DateFormatter([.withInternetDateTime, .withFractionalSeconds])
        }
    }

    static var relativeDateTime: RelativeDateTimeFormatter {
        ThreadLocalFormatterCache.formatter(forKey: "relativeDateTime") {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter
        }
    }

    static var ptBrDayMonthYearHoursMinutesSeconds: DateFormatter {
        ThreadLocalFormatterCache.formatter(forKey: "ptBrDayMonthYearHoursMinutesSeconds") {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt-BR")
            formatter.dateFormat = "dd/MM/yyyy hh:mm:ss"
            formatter.calendar = Calendar(identifier: .gregorian)
            return formatter
        }
    }

    static var ptBrDayMonthYearHoursMinutes: DateFormatter {
        ThreadLocalFormatterCache.formatter(forKey: "ptBrDayMonthYearHoursMinutes") {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt-BR")
            formatter.dateFormat = "dd/MM/yyyy hh:mm"
            formatter.calendar = Calendar(identifier: .gregorian)
            return formatter
        }
    }

    static var yyyyMMdd: DateFormatter {
        ThreadLocalFormatterCache.formatter(forKey: "yyyyMMdd") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }
    }

    static var apiDateInput: DateFormatter {
        ThreadLocalFormatterCache.formatter(forKey: "apiDateInput") {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            return formatter
        }
    }

    static var apiDateOutput: DateFormatter {
        ThreadLocalFormatterCache.formatter(forKey: "apiDateOutput") {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt-BR")
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            return formatter
        }
    }

    static var episodeAbsoluteDate: DateFormatter {
        ThreadLocalFormatterCache.formatter(forKey: "episodeAbsoluteDate") {
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.setLocalizedDateFormatFromTemplate("d MMMM y")
            return formatter
        }
    }
}

extension Date {
    var iso8601withFractionalSeconds: String { return Formatter.iso8601withFractionalSeconds.string(from: self) }
}

extension String {
    var iso8601withFractionalSeconds: Date? { return Formatter.iso8601withFractionalSeconds.date(from: self) }
}

extension Date {

    internal func formattedDayMonthYearHoursMinutesSeconds() -> String {
        Formatter.ptBrDayMonthYearHoursMinutesSeconds.string(from: self)
    }

    internal func formattedDayMonthYearHoursMinutes() -> String {
        Formatter.ptBrDayMonthYearHoursMinutes.string(from: self)
    }

    var asRelativeDateTime: String {
        Formatter.relativeDateTime.localizedString(for: self, relativeTo: Date.now)
    }
}

extension Date {
    static func isDateWithinLast7Days(_ date: Date?) -> Bool {
        guard let date = date else {
            return false
        }
        
        let calendar = Calendar.current
        let currentDate = calendar.startOfDay(for: .now)
        
        // -8 used below to compensate for +3 hours .now has
        if let last7Days = calendar.date(byAdding: .day, value: -8, to: currentDate) {
            return calendar.isDate(date, inSameDayAs: currentDate) || date > last7Days
        }
        
        return false
    }
}

extension Date {
    var onlyDate: Date? {
        get {
            let calender = Calendar.current
            var dateComponents = calender.dateComponents([.year, .month, .day], from: self)
            dateComponents.timeZone = NSTimeZone.system
            return calender.date(from: dateComponents)
        }
    }
}

extension String {

    var asRelativeDateTime: String? {
        guard let date = Formatter.iso8601withFractionalSeconds.date(from: self) else {
            return nil
        }
        return Formatter.relativeDateTime.localizedString(for: date, relativeTo: Date())
    }
}

extension Date {

    func minutesPassed(_ minutes: Int) -> Bool {
        let diffComponents = Calendar.current.dateComponents([.minute], from: self, to: .now)
        let difference = diffComponents.minute!
        return difference >= minutes
    }

    static func dateAsString(addingDays daysToAdd: Int, referenceDate: Date = Date.now) -> String {
        var dayComponent = DateComponents()
        dayComponent.day = daysToAdd
        let newDate = Calendar.current.date(byAdding: dayComponent, to: referenceDate)
        if let newDate = newDate {
            return Formatter.yyyyMMdd.string(from: newDate)
        } else {
            return ""
        }
    }
}

extension Date {

    var minutesAndSecondsFromNow: String {
        let twoMinutesFromLastUpdate = Calendar.current.date(byAdding: .minute, value: 2, to: self)

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
