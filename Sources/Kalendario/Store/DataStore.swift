import Foundation
import Observation

/// Keeps one unreadable element from failing the whole array.
private struct Failable<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}

struct KalendarioSnapshot: Codable {
    var version: Int = 1
    var events: [CalendarEvent] = []
    var notes: [StickyNote] = []
    var locations: [WorkLocation] = []
    /// Work location per day, keyed "yyyy-MM-dd" in the local calendar.
    var assignments: [String: UUID] = [:]

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, events, notes, locations, assignments
    }

    // Tolerant decoding: every field is optional in the file, so data written by an older
    // version (or edited by hand) keeps loading instead of being reset.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        events = Self.decode(container, key: .events)
        notes = Self.decode(container, key: .notes)
        locations = Self.decode(container, key: .locations)
        assignments = try container.decodeIfPresent([String: UUID].self, forKey: .assignments) ?? [:]
    }

    private static func decode<Element: Decodable>(_ container: KeyedDecodingContainer<CodingKeys>,
                                                   key: CodingKeys) -> [Element] {
        guard let wrapped = try? container.decodeIfPresent([Failable<Element>].self, forKey: key) else { return [] }
        let values = wrapped.compactMap(\.value)
        if wrapped.count != values.count {
            NSLog("Kalendario: skipped \(wrapped.count - values.count) unreadable \(key.stringValue)")
        }
        return values
    }
}

@Observable
final class DataStore {
    var events: [CalendarEvent] = []
    var notes: [StickyNote] = []
    var locations: [WorkLocation] = []
    /// Work location per day, keyed "yyyy-MM-dd" in the local calendar.
    var assignments: [String: UUID] = [:]

    private let storageURL: URL?
    private let ioQueue = DispatchQueue(label: "local.kalendario.io", qos: .utility)
    private var pendingWrite: DispatchWorkItem?

    init(inMemory: Bool = false) {
        if inMemory {
            storageURL = nil
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            storageURL = base
                .appendingPathComponent("Kalendario", isDirectory: true)
                .appendingPathComponent("kalendario.json")
        }
        bootstrap()
    }

    private func bootstrap() {
        guard !loadFromDisk() else { return }
        // The app starts empty on purpose: the sample week is used by the static previews only.
        if storageURL == nil { seedExampleWeek() }
    }

    var storageLocation: String { storageURL?.path ?? "in memory" }

    // MARK: - Persistence

    private func loadFromDisk() -> Bool {
        guard let url = storageURL, let data = try? Data(contentsOf: url) else { return false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let snapshot = try decoder.decode(KalendarioSnapshot.self, from: data)
            events = snapshot.events
            notes = snapshot.notes
            locations = snapshot.locations
            assignments = snapshot.assignments
            return true
        } catch {
            // Never lose data: keep the unreadable file beside the good one before starting over.
            let backup = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? data.write(to: backup, options: .atomic)
            NSLog("Kalendario: the data file could not be read (\(error.localizedDescription)); a copy was kept as \(backup.lastPathComponent)")
            return false
        }
    }

    func scheduleSave() {
        guard let url = storageURL else { return }
        var snapshot = KalendarioSnapshot()
        snapshot.events = events
        snapshot.notes = notes
        snapshot.locations = locations
        snapshot.assignments = assignments

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }

        pendingWrite?.cancel()
        let work = DispatchWorkItem {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("Kalendario: save failed (\(error.localizedDescription))")
            }
        }
        pendingWrite = work
        ioQueue.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    // MARK: - Queries

    func events(on day: Date) -> [CalendarEvent] {
        events
            .filter { WeekMath.calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    func events(inWeek monday: Date) -> [CalendarEvent] {
        let days = WeekMath.daysInWeek(from: monday)
        return events.filter { event in
            days.contains { WeekMath.isSameDay($0, event.start) }
        }
    }

    func notes(inWeek monday: Date) -> [StickyNote] {
        notes
            .filter { WeekMath.isSameDay($0.weekStart, monday) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func note(id: UUID) -> StickyNote? { notes.first { $0.id == id } }

    func eventIndex(of id: UUID) -> Int? { events.firstIndex { $0.id == id } }

    func noteIndex(of id: UUID) -> Int? { notes.firstIndex { $0.id == id } }

    // MARK: - Event mutations

    @discardableResult
    func addEvent(day: Date, hour: Int, minute: Int = 0) -> CalendarEvent {
        var event = CalendarEvent()
        event.start = WeekMath.makeDate(day: day, hour: hour, minute: minute)
        events.append(event)
        scheduleSave()
        return event
    }

    func upsert(_ event: CalendarEvent) {
        if let index = eventIndex(of: event.id) {
            events[index] = event
        } else {
            events.append(event)
        }
        scheduleSave()
    }

    func delete(eventID: UUID) {
        events.removeAll { $0.id == eventID }
        scheduleSave()
    }

    func toggleCompletion(eventID: UUID) {
        guard let index = eventIndex(of: eventID) else { return }
        events[index].isCompleted.toggle()
        scheduleSave()
    }

    // MARK: - Sticky note mutations

    @discardableResult
    func addNote(inWeek monday: Date, color: NoteColor? = nil) -> StickyNote {
        var note = StickyNote()
        note.weekStart = monday
        note.color = color ?? .yellow
        notes.append(note)
        scheduleSave()
        return note
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        scheduleSave()
    }

    func duplicateNote(id: UUID) {
        guard var copy = note(id: id) else { return }
        copy.id = UUID()
        copy.createdAt = Date()
        copy.todos = copy.todos.map { TodoItem(id: UUID(), text: $0.text, isDone: false) }
        notes.append(copy)
        scheduleSave()
    }

    func moveNote(id: UUID, toWeek monday: Date) {
        guard let index = noteIndex(of: id) else { return }
        notes[index].weekStart = monday
        scheduleSave()
    }

    func addTodo(noteID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = noteIndex(of: noteID) else { return }
        notes[index].todos.append(TodoItem(text: trimmed))
        scheduleSave()
    }

    func toggleTodo(noteID: UUID, todoID: UUID) {
        guard let noteIdx = noteIndex(of: noteID),
              let todoIdx = notes[noteIdx].todos.firstIndex(where: { $0.id == todoID }) else { return }
        notes[noteIdx].todos[todoIdx].isDone.toggle()
        scheduleSave()
    }

    func deleteTodo(noteID: UUID, todoID: UUID) {
        guard let index = noteIndex(of: noteID) else { return }
        notes[index].todos.removeAll { $0.id == todoID }
        scheduleSave()
    }

    func clearAll() {
        events = []
        notes = []
        scheduleSave()
    }

    // MARK: - Work locations

    func location(id: UUID) -> WorkLocation? {
        locations.first { $0.id == id }
    }

    func locationIndex(of id: UUID) -> Int? {
        locations.firstIndex { $0.id == id }
    }

    func location(on day: Date) -> WorkLocation? {
        guard let id = assignments[WeekMath.dayKey(day)] else { return nil }
        return location(id: id)
    }

    func assignLocation(_ id: UUID?, to day: Date) {
        let key = WeekMath.dayKey(day)
        if let id {
            assignments[key] = id
        } else {
            assignments.removeValue(forKey: key)
        }
        scheduleSave()
    }

    @discardableResult
    func addLocation(name: String = "", color: NoteColor? = nil) -> WorkLocation {
        let palette = NoteColor.allCases
        var location = WorkLocation()
        location.name = name
        location.color = color ?? palette[locations.count % palette.count]
        locations.append(location)
        scheduleSave()
        return location
    }

    func deleteLocation(id: UUID) {
        locations.removeAll { $0.id == id }
        assignments = assignments.filter { $0.value != id }
        scheduleSave()
    }

    func assignedDays(inWeek monday: Date) -> Int {
        WeekMath.daysInWeek(from: monday).filter { location(on: $0) != nil }.count
    }

    // MARK: - GitHub issues

    func eventIndex(forIssue repo: String, number: Int) -> Int? {
        events.firstIndex { $0.issue?.repo == repo && $0.issue?.number == number }
    }

    /// Places the freshly imported issues on the calendar, one slot every `stepMinutes`.
    /// Issues already on the calendar are refreshed instead of duplicated.
    @discardableResult
    func importIssues(_ issues: [GitHubIssue], repo: String, day: Date, hour: Int,
                      stepMinutes: Int, durationMinutes: Int, category: EventCategory) -> Int {
        var created = 0
        var slot = 0

        for issue in issues {
            if let index = eventIndex(forIssue: repo, number: issue.number) {
                apply(issue, repo: repo, to: index, rename: true)
                continue
            }

            var event = CalendarEvent()
            event.title = "\(issue.reference) \(issue.title)"
            let targetDay = issue.milestoneDue ?? day
            let base = WeekMath.makeDate(day: targetDay, hour: hour)
            event.start = WeekMath.calendar.date(byAdding: .minute, value: slot * stepMinutes, to: base) ?? base
            event.durationMinutes = durationMinutes
            event.category = category
            event.notes = issue.notesPreview
            event.isCompleted = issue.isClosed
            event.issue = IssueRef(repo: repo, number: issue.number, url: issue.url,
                                   labels: issue.labels, state: issue.state, updatedAt: issue.updatedAt)
            events.append(event)
            slot += 1
            created += 1
        }

        scheduleSave()
        return created
    }

    /// Refreshes the events that were imported from GitHub. Returns how many were touched.
    @discardableResult
    func applyIssueUpdates(_ issues: [GitHubIssue], repo: String) -> Int {
        var touched = 0
        for issue in issues {
            guard let index = eventIndex(forIssue: repo, number: issue.number) else { continue }
            apply(issue, repo: repo, to: index, rename: true)
            touched += 1
        }
        if touched > 0 { scheduleSave() }
        return touched
    }

    private func apply(_ issue: GitHubIssue, repo: String, to index: Int, rename: Bool) {
        if rename { events[index].title = "\(issue.reference) \(issue.title)" }
        events[index].notes = issue.notesPreview
        events[index].isCompleted = issue.isClosed
        events[index].issue = IssueRef(repo: repo, number: issue.number, url: issue.url,
                                       labels: issue.labels, state: issue.state, updatedAt: issue.updatedAt)
    }

    var importedRepositories: [String] {
        Array(Set(events.compactMap { $0.issue?.repo })).sorted()
    }

    var importedIssueCount: Int {
        events.filter { $0.issue != nil }.count
    }

    // MARK: - Demo data

    func seedExampleWeek() {
        let monday = WeekMath.startOfWeek(Date())

        func start(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            WeekMath.makeDate(day: WeekMath.date(dayOfWeek: offset, inWeekFrom: monday), hour: hour, minute: minute)
        }

        func make(_ title: String, _ offset: Int, _ hour: Int, _ minute: Int = 0,
                  _ duration: Int, _ category: EventCategory, done: Bool = false, notes: String = "") -> CalendarEvent {
            CalendarEvent(id: UUID(), title: title, start: start(offset, hour, minute),
                          durationMinutes: duration, category: category, notes: notes, isCompleted: done)
        }

        events = [
            make("Weekly planning", 0, 9, 0, 60, .work, notes: "Review priorities and goals"),
            make("Team sync", 0, 14, 30, 45, .work),
            make("Gym", 1, 8, 30, 60, .health),
            make("Project review", 2, 10, 0, 90, .work, notes: "Demo with the stakeholder"),
            make("Lunch with Marco", 3, 13, 0, 60, .personal),
            make("Weekly release", 4, 16, 0, 60, .work, done: true),
            make("Farmers market", 5, 10, 30, 90, .personal),
            make("Reading", 6, 19, 0, 120, .other),
            make("Morning run", 5, 8, 0, 45, .sport),
            make("Dinner with family", 6, 20, 0, 90, .family)
        ]

        notes = [
            StickyNote(id: UUID(), title: "Weekly shopping", color: .yellow, weekStart: monday,
                       todos: [TodoItem(text: "Milk"), TodoItem(text: "Bread"),
                               TodoItem(text: "Coffee", isDone: true), TodoItem(text: "Fruit and vegetables")],
                       createdAt: Date()),
            StickyNote(id: UUID(), title: "Work", color: .yellow, weekStart: monday,
                       todos: [TodoItem(text: "Send the report", isDone: true),
                               TodoItem(text: "Reply to Sara"), TodoItem(text: "Prepare the slides")],
                       createdAt: Date().addingTimeInterval(60)),
            StickyNote(id: UUID(), title: "House", color: .yellow, weekStart: monday,
                       todos: [TodoItem(text: "Laundry", isDone: true), TodoItem(text: "Pay the bill", isDone: true)],
                       createdAt: Date().addingTimeInterval(120))
        ]

        let home = WorkLocation(name: "Home", color: .blue)
        let office = WorkLocation(name: "Office", color: .green)
        let client = WorkLocation(name: "Client site", color: .orange)
        locations = [home, office, client]

        func day(_ offset: Int) -> Date {
            WeekMath.date(dayOfWeek: offset, inWeekFrom: monday)
        }

        assignments = [
            WeekMath.dayKey(day(0)): home.id,
            WeekMath.dayKey(day(1)): office.id,
            WeekMath.dayKey(day(2)): office.id,
            WeekMath.dayKey(day(3)): client.id,
            WeekMath.dayKey(day(4)): home.id
        ]
    }
}