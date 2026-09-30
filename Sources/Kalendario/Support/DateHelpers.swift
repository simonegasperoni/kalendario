import Foundation

enum WeekMath {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    static func startOfWeek(_ date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        if let start = calendar.date(from: components) {
            return calendar.startOfDay(for: start)
        }
        return calendar.startOfDay(for: date)
    }

    static func daysInWeek(from monday: Date) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    static func addWeeks(_ count: Int, to monday: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: count, to: monday) ?? monday
    }

    static func date(dayOfWeek offset: Int, inWeekFrom monday: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
    }

    static func weekNumber(_ date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }

    static func isWeekend(_ date: Date) -> Bool { calendar.isDateInWeekend(date) }

    /// Stable day key ("yyyy-MM-dd") used to remember the work location of each day.
    static func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func minutesFromMidnight(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func combine(day: Date, time: Date) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        return make(year: dayParts.year, month: dayParts.month, day: dayParts.day,
                    hour: timeParts.hour, minute: timeParts.minute) ?? day
    }

    static func makeDate(day: Date, hour: Int, minute: Int = 0) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return make(year: parts.year, month: parts.month, day: parts.day, hour: hour, minute: minute) ?? day
    }

    private static func make(year: Int?, month: Int?, day: Int?, hour: Int?, minute: Int?) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    static func hourLabel(_ hour: Int) -> String { String(format: "%02d", hour) }

    static func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}

enum DateText {
    static let weekdayShort = make("EEE")
    static let weekdayLong = make("EEEE")
    static let dayNumber = make("d")
    static let monthShort = make("MMM")
    static let monthLong = make("MMMM")
    static let year = make("yyyy")
    static let hourMinute = make("HH:mm")
    static let monthDayShort = make("MMM d")
    static let monthDayYear = make("MMM d, yyyy")
    static let fullDay = make("EEEE, MMMM d")

    static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = WeekMath.calendar
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    static func capitalize(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: ".", with: "")
    }

    static func weekdayTitle(_ date: Date) -> String {
        capitalize(clean(weekdayShort.string(from: date)))
    }

    static func dayTitle(_ date: Date) -> String {
        capitalize(clean(weekdayLong.string(from: date)))
    }

    static func weekTitle(_ monday: Date) -> String {
        let days = WeekMath.daysInWeek(from: monday)
        guard let sunday = days.last else { return "" }
        let start = monthDayShort.string(from: monday)
        let end = monthDayYear.string(from: sunday)
        return "Week \(WeekMath.weekNumber(monday)) · \(start) – \(end)"
    }

    static func longDay(_ date: Date) -> String {
        fullDay.string(from: date)
    }

    static func relativeDay(_ date: Date) -> String {
        let calendar = WeekMath.calendar
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return longDay(date)
    }
}