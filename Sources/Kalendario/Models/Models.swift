import Foundation
import SwiftUI

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    // Raw values stay in Italian: they are what is written in the user's JSON data file.
    case work = "lavoro"
    case personal = "personale"
    case health = "salute"
    case study = "studio"
    case other = "altro"
    case sport = "sport"
    case home = "casa"
    case family = "famiglia"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health"
        case .study: return "Study"
        case .other: return "Other"
        case .sport: return "Sport"
        case .home: return "Home"
        case .family: return "Family"
        }
    }

    var symbol: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .study: return "book.fill"
        case .other: return "star.fill"
        case .sport: return "figure.run"
        case .home: return "house.fill"
        case .family: return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .work: return Color(hex: "#1F4E7E")
        case .personal: return Color(hex: "#4E9A6B")
        case .health: return Color(hex: "#5AA5D8")
        case .study: return Color(hex: "#7A5CA8")
        case .other: return Color(hex: "#8A7F6D")
        case .sport: return Color(hex: "#2F8F8A")
        case .home: return Color(hex: "#C08A2E")
        case .family: return Color(hex: "#9B548C")
        }
    }
}

struct CalendarEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var start: Date = Date()
    var durationMinutes: Int = 60
    var category: EventCategory = .work
    var notes: String = ""
    var isCompleted: Bool = false
    /// Set when the event comes from an imported GitHub issue; nil for hand-made events.
    var issue: IssueRef?

    var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    var timeRange: String {
        "\(DateText.hourMinute.string(from: start))–\(DateText.hourMinute.string(from: end))"
    }
}

/// Pointer to the GitHub issue an event was imported from, so that the event can be
/// refreshed later and traced back to its source.
struct IssueRef: Codable, Hashable {
    var repo: String
    var number: Int
    var url: String
    var labels: [String]
    var state: String
    var updatedAt: Date?

    init(repo: String, number: Int, url: String, labels: [String] = [],
         state: String = "open", updatedAt: Date? = nil) {
        self.repo = repo
        self.number = number
        self.url = url
        self.labels = labels
        self.state = state
        self.updatedAt = updatedAt
    }

    // Tolerant decoding: a missing field in an older data file must not fail the whole file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repo = try container.decodeIfPresent(String.self, forKey: .repo) ?? ""
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? 0
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
        state = try container.decodeIfPresent(String.self, forKey: .state) ?? "open"
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var isClosed: Bool { state.caseInsensitiveCompare("closed") == .orderedSame }

    var shortLabel: String { "\(repo)#\(number)" }

    var labelsText: String { labels.isEmpty ? "—" : labels.joined(separator: ", ") }
}

/// A place you can work from: home, an office, a co-working space.
/// The colour comes from the shared tag palette (`NoteColor`), so locations and sticky notes
/// stay visually consistent.
struct WorkLocation: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var color: NoteColor

    init(id: UUID = UUID(), name: String = "", color: NoteColor = .blue) {
        self.id = id
        self.name = name
        self.color = color
    }

    // Tolerant decoding: a missing field must not fail the whole data file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        color = try container.decodeIfPresent(NoteColor.self, forKey: .color) ?? .blue
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled place" : trimmed
    }
}

enum NoteColor: String, Codable, CaseIterable, Identifiable {
    // Raw values stay in Italian: they are what is written in the user's JSON data file.
    case yellow = "giallo"
    case pink = "rosa"
    case blue = "azzurro"
    case green = "verde"
    case purple = "lilla"
    case orange = "arancio"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yellow: return "Yellow"
        case .pink: return "Pink"
        case .blue: return "Blue"
        case .green: return "Green"
        case .purple: return "Purple"
        case .orange: return "Orange"
        }
    }

    var paper: Color {
        switch self {
        case .yellow: return Color.dynamic(light: "#FFE9A8", dark: "#453A20")
        case .pink: return Color.dynamic(light: "#FFD8DF", dark: "#45262E")
        case .blue: return Color.dynamic(light: "#D2E4F8", dark: "#1F3547")
        case .green: return Color.dynamic(light: "#D8EDD1", dark: "#22371E")
        case .purple: return Color.dynamic(light: "#E5DBF8", dark: "#312745")
        case .orange: return Color.dynamic(light: "#FFDCBB", dark: "#45301E")
        }
    }

    /// Strong version of the colour, used for solid fills (tags, swatches, progress bars).
    var edgeHex: String {
        switch self {
        case .yellow: return "#D9A521"
        case .pink: return "#D9637F"
        case .blue: return "#4C86C0"
        case .green: return "#55943F"
        case .purple: return "#8161BE"
        case .orange: return "#D07F31"
        }
    }

    var edge: Color { Color(hex: edgeHex) }

    /// Darker, saturated version of the colour, for tags that must be clearly visible on the
    /// paper background. All six are dark enough for white text (contrast ≥ 4.8:1).
    var tagFillHex: String {
        switch self {
        case .yellow: return "#8A6A0F"
        case .pink: return "#B33F5C"
        case .blue: return "#2F6BA6"
        case .green: return "#3F7A2E"
        case .purple: return "#6A48A8"
        case .orange: return "#A85F1C"
        }
    }

    var tagFill: Color { Color(hex: tagFillHex) }

    /// Text colour to use on a solid `tagFill` background: whichever of white or the dark ink
    /// has the higher WCAG contrast against the fill, so every tag stays readable.
    var tagText: Color {
        func linear(_ raw: Double) -> Double {
            raw <= 0.03928 ? raw / 12.92 : pow((raw + 0.055) / 1.055, 2.4)
        }

        var value: UInt64 = 0
        _ = Scanner(string: tagFillHex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
        let channels = [Double((value >> 16) & 0xFF) / 255,
                        Double((value >> 8) & 0xFF) / 255,
                        Double(value & 0xFF) / 255].map(linear)
        let luminance = 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

        let contrastWithWhite = 1.05 / (luminance + 0.05)
        let contrastWithInk = (luminance + 0.05) / (0.02 + 0.05)
        return contrastWithWhite >= contrastWithInk ? Color.white : Color(hex: "#241A08")
    }

    var ink: Color {
        switch self {
        case .yellow: return Color.dynamic(light: "#47390E", dark: "#FFEEC0")
        case .pink: return Color.dynamic(light: "#481E27", dark: "#FFDCE4")
        case .blue: return Color.dynamic(light: "#152E3D", dark: "#D6E9FA")
        case .green: return Color.dynamic(light: "#1D3116", dark: "#DCF2D6")
        case .purple: return Color.dynamic(light: "#2A1F3E", dark: "#E8DFF9")
        case .orange: return Color.dynamic(light: "#3E2712", dark: "#FFE4CA")
        }
    }
}

struct TodoItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String = ""
    var isDone: Bool = false
}

struct StickyNote: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var color: NoteColor = .yellow
    var weekStart: Date = Date()
    var todos: [TodoItem] = []
    var createdAt: Date = Date()

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sticky note" : trimmed
    }

    var doneCount: Int { todos.filter { $0.isDone }.count }

    var progress: Double {
        todos.isEmpty ? 0 : Double(doneCount) / Double(todos.count)
    }
}