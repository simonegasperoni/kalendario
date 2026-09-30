import Foundation
import Observation

@Observable
final class EventDraft: Identifiable {
    let id = UUID()
    var event: CalendarEvent
    var isNew: Bool

    init(event: CalendarEvent, isNew: Bool) {
        self.event = event
        self.isNew = isNew
    }
}

/// Application state. `@State` is a macro whose implementation plugin ships only with
/// Xcode, so every piece of mutable UI state lives here and is observed through Observation.
@Observable
final class AppState {
    static let shared = AppState()

    var store = DataStore()

    var weekStart: Date = WeekMath.startOfWeek(Date())
    var editor: EventDraft?
    var hoveredKey: String?
    var todoDrafts: [UUID: String] = [:]
    var didScroll = false

    private init() {}

    var defaultHour: Int {
        min(22, max(6, WeekMath.calendar.component(.hour, from: Date())))
    }

    // MARK: - Navigation

    func goToToday() { weekStart = WeekMath.startOfWeek(Date()) }
    func previousWeek() { weekStart = WeekMath.addWeeks(-1, to: weekStart) }
    func nextWeek() { weekStart = WeekMath.addWeeks(1, to: weekStart) }

    // MARK: - Event editor

    func newEvent(day: Date, hour: Int) {
        let event = store.addEvent(day: day, hour: hour)
        editor = EventDraft(event: event, isNew: true)
    }

    func newEventInCurrentWeek() {
        newEvent(day: weekStart, hour: defaultHour)
    }

    func edit(_ event: CalendarEvent) {
        editor = EventDraft(event: event, isNew: false)
    }

    func cancelEditor() {
        if let editor, editor.isNew { store.delete(eventID: editor.event.id) }
        editor = nil
    }

    func saveEditor() {
        guard let editor else { return }
        var event = editor.event
        if event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            event.title = "Untitled"
        }
        event.durationMinutes = max(5, event.durationMinutes)
        store.upsert(event)
        self.editor = nil
    }

    // MARK: - Sticky notes

    func newNote() { store.addNote(inWeek: weekStart) }

    func todoDraft(for id: UUID) -> String { todoDrafts[id] ?? "" }

    func setTodoDraft(_ text: String, for id: UUID) { todoDrafts[id] = text }

    func commitTodoDraft(for id: UUID) {
        let text = todoDrafts[id] ?? ""
        todoDrafts[id] = ""
        store.addTodo(noteID: id, text: text)
    }

    // MARK: - Work locations

    var showLocations = false
    /// Day key ("yyyy-MM-dd") of the cell whose place picker is open, if any.
    var locationPickerDay: String?

    func openLocations() {
        locationPickerDay = nil
        showLocations = true
    }

    /// Creates a place and opens the manager so it can be named straight away.
    func addLocationAndManage() {
        store.addLocation()
        showLocations = true
    }

    // MARK: - GitHub issues

    var showIssueImport = false
    let issueImport = IssueImportModel()

    func openIssueImport() {
        issueImport.persist()
        issueImport.day = weekStart
        issueImport.status = ""
        showIssueImport = true
    }

    func closeIssueImport() {
        showIssueImport = false
    }

    /// Loads the issues of the repository configured in the sheet.
    func loadIssues() {
        let model = issueImport
        model.persist()

        let repository = GitHubClient.normalize(model.repository)
        guard GitHubClient.isValid(repository) else {
            model.status = GitHubError.invalidRepository.errorDescription ?? "Invalid repository."
            return
        }

        let state = model.includeClosed ? "all" : "open"
        let labels = model.labelList
        let limit = model.limit
        let client = GitHubClient(token: TokenStore.token())

        model.isLoading = true
        model.status = ""

        Task { @MainActor in
            do {
                let issues = try await client.issues(repository: repository,
                                                     state: state,
                                                     labels: labels,
                                                     limit: limit)
                model.issues = issues
                model.loadedRepository = repository
                model.selected = Set(issues.map(\.number))
                model.status = issues.isEmpty
                    ? "No issues matched those filters."
                    : "\(issues.count) issues from \(repository)."
            } catch {
                model.issues = []
                model.status = AppState.message(for: error)
            }
            model.isLoading = false
        }
    }

    /// Places the selected issues on the calendar, in the week shown in the plan.
    func importSelectedIssues() {
        let model = issueImport
        let chosen = model.selectedIssues
        guard !chosen.isEmpty else {
            model.status = "Select at least one issue first."
            return
        }

        let repository = GitHubClient.normalize(model.repository)
        let created = store.importIssues(chosen,
                                         repo: repository,
                                         day: model.day,
                                         hour: model.hour,
                                         stepMinutes: model.stepMinutes,
                                         durationMinutes: model.durationMinutes,
                                         category: model.category)
        let refreshed = chosen.count - created

        weekStart = WeekMath.startOfWeek(model.day)
        var parts = ["\(created) issue\(created == 1 ? "" : "s") placed on the calendar"]
        if refreshed > 0 {
            parts.append("\(refreshed) already there were refreshed")
        }
        model.status = parts.joined(separator: ", ") + "."
        model.selected = []
    }

    /// Re-reads every repository already on the calendar and updates its events.
    func refreshImportedIssues() {
        let model = issueImport
        let repositories = store.importedRepositories
        guard !repositories.isEmpty else {
            model.status = "No imported issues on the calendar yet."
            return
        }

        let client = GitHubClient(token: TokenStore.token())
        let dataStore = store

        model.isRefreshing = true
        model.status = ""

        Task { @MainActor in
            var touched = 0
            var failed: [String] = []
            for repository in repositories {
                do {
                    let issues = try await client.issues(repository: repository, state: "all", limit: 100)
                    touched += dataStore.applyIssueUpdates(issues, repo: repository)
                } catch {
                    failed.append(repository)
                }
            }
            model.isRefreshing = false
            if failed.isEmpty {
                model.status = "Updated \(touched) imported events."
            } else {
                model.status = "Updated \(touched) events, but could not read: \(failed.joined(separator: ", "))."
            }
        }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - Hover

    func isHovered(_ key: String) -> Bool { hoveredKey == key }

    func setHovered(_ key: String, _ value: Bool) {
        if value {
            hoveredKey = key
        } else if hoveredKey == key {
            hoveredKey = nil
        }
    }
}