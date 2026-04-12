import Foundation

enum AppFormatters {
    private static let chineseLocale = Locale(identifier: "zh_CN")
    private static let formatterLock = NSLock()
    private static var formatterCache: [String: DateFormatter] = [:]
    private static var configuredCurrencyCode = "CNY"

    static func setCurrencyCode(_ rawValue: String) {
        formatterLock.lock()
        configuredCurrencyCode = AppSettings.normalizedCurrencyCode(rawValue)
        formatterLock.unlock()
    }

    static func currency(_ value: Double) -> String {
        formatterLock.lock()
        let code = configuredCurrencyCode
        formatterLock.unlock()

        return value.formatted(
            .currency(code: code)
                .presentation(.narrow)
                .precision(.fractionLength(0...0))
        )
    }

    static func day(_ date: Date) -> String { string(from: date, format: "M月d日 EEE") }
    static func fullDate(_ date: Date) -> String { string(from: date, format: "yyyy年M月d日 HH:mm") }
    static func time(_ date: Date) -> String { string(from: date, format: "HH:mm") }
    static func relativeDate(_ date: Date, reference: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: reference)).day ?? 0
        if abs(days) <= 7 {
            return days >= 0 ? "\(days) 天前" : "\(-days) 天后"
        }
        return shortDate(date)
    }
    static func shortDate(_ date: Date) -> String { string(from: date, format: "yyyy年M月d日") }
    static func shortMonthDay(_ date: Date) -> String { string(from: date, format: "M月d日") }
    static func weekday(_ date: Date) -> String { string(from: date, format: "EEEE") }
    static func monthYear(_ date: Date) -> String { string(from: date, format: "yyyy年M月") }

    static func timeRange(start: Date, end: Date) -> String {
        let startText = string(from: start, format: "HH:mm")
        let endText = string(from: end, format: "HH:mm")
        return "\(startText) — \(endText)"
    }

    static func dayAndTime(_ date: Date) -> String {
        "\(relativeDay(date)) · \(string(from: date, format: "HH:mm"))"
    }

    static func weekRange(start: Date, end: Date) -> String {
        "\(shortMonthDay(start)) - \(shortMonthDay(end))"
    }

    static func reorderedShortWeekdaySymbols(firstWeekday: Int) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        guard symbols.isEmpty == false else { return [] }

        let first = max(min(firstWeekday - 1, symbols.count - 1), 0)
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    static func relativeDay(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return day(date)
    }

    static func relativeDueText(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "今天到期" }
        if calendar.isDateInTomorrow(date) { return "明天到期" }
        let today = calendar.startOfDay(for: .now)
        if date < today { return "已逾期 · \(shortMonthDay(date))" }
        return shortMonthDay(date)
    }

    static func countdownText(to date: Date, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        switch days {
        case ..<0: return "已过 \(-days) 天"
        case 0: return "今天"
        case 1: return "1 天后"
        default: return "\(days) 天后"
        }
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func normalizedSearchText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matchesSearch(_ query: String, terms: [String]) -> Bool {
        let normalizedQuery = normalizedSearchText(query)
        guard normalizedQuery.isEmpty == false else { return true }

        let keywords = normalizedQuery
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "，" || $0 == "/" })
            .map(String.init)

        guard keywords.isEmpty == false else { return true }

        let normalizedTerms = terms.map(normalizedSearchText)
        return keywords.allSatisfy { keyword in
            normalizedTerms.contains { $0.contains(keyword) }
        }
    }

    static func sanitizedPhoneNumber(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "+" }
    }

    private static func string(from date: Date, format: String) -> String {
        let formatter = cachedFormatter(for: format)
        return formatter.string(from: date)
    }

    private static func cachedFormatter(for format: String) -> DateFormatter {
        formatterLock.lock()
        defer { formatterLock.unlock() }

        if let formatter = formatterCache[format] {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.locale = chineseLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        formatterCache[format] = formatter
        return formatter
    }
}
