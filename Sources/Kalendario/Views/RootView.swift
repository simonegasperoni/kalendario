import SwiftUI

struct RootView: View {
    @Environment(DataStore.self) private var store
    private let app = AppState.shared

    var body: some View {
        let editor = app.editor
        let showIssues = app.showIssueImport
        let showSettings = app.showSettings

        VStack(spacing: 0) {
            HeaderBar()
                .sheet(isPresented: Binding(get: { showIssues }, set: { app.showIssueImport = $0 })) {
                    IssueImportView(model: app.issueImport)
                }

            Separator()

            SystemStatsRow()

            Separator()

            WeekGridView(weekStart: app.weekStart,
                         onCreateEvent: { day, hour in app.newEvent(day: day, hour: hour) },
                         onEditEvent: { event in app.edit(event) })

            Separator()

            GitHubMetaRow()

            Separator()

            NotesStripView(weekStart: app.weekStart)

            Separator()

            FooterView(weekStart: app.weekStart)
                .sheet(isPresented: Binding(get: { showSettings },
                                            set: { app.showSettings = $0 })) {
                    SettingsView()
                        .environment(store)
                }
        }
        .background(Theme.paper)
        .sheet(item: Binding(get: { editor }, set: { app.editor = $0 })) { draft in
            EventEditorView(draft: draft)
                .environment(store)
        }
        .onAppear { app.weather.refreshIfStale() }
        .onChange(of: store.events) { _, _ in store.scheduleSave() }
        .onChange(of: store.notes) { _, _ in store.scheduleSave() }
        .onChange(of: store.locations) { _, _ in store.scheduleSave() }
        .onChange(of: store.assignments) { _, _ in store.scheduleSave() }
    }
}

struct FooterView: View {
    @Environment(DataStore.self) private var store

    let weekStart: Date

    var body: some View {
        HStack(spacing: 16) {
            WeekSummaryChips(weekStart: weekStart)

            Spacer(minLength: 8)

            ViewThatFits(in: .horizontal) {
                hint("Use + in a day to add an event · ⌘N new event · ⌘T back to today")
                hint("⌘N new event · ⌘T today")
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 34)
        .background(Theme.paperElevated.opacity(0.5))
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Theme.tinyFont)
            .foregroundStyle(Theme.inkFaint)
            .lineLimit(1)
            .fixedSize()
    }
}

/// The counters of the week, shown in the bottom bar.
struct WeekSummaryChips: View {
    @Environment(DataStore.self) private var store

    let weekStart: Date

    var body: some View {
        let weekEvents = store.events(inWeek: weekStart)
        let done = weekEvents.filter { $0.isCompleted }.count
        let weekNotes = store.notes(inWeek: weekStart)
        let todos = weekNotes.flatMap { $0.todos }
        let todosDone = todos.filter { $0.isDone }.count

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                StatChip(symbol: "calendar", text: "\(weekEvents.count) events")
                StatChip(symbol: "checkmark.circle", text: "\(done) done")
                StatChip(symbol: "note.text", text: "\(weekNotes.count) sticky notes")
                StatChip(symbol: "checklist", text: todos.isEmpty ? "0/0" : "\(todosDone)/\(todos.count)")
            }
            HStack(spacing: 6) {
                StatChip(symbol: "calendar", text: "\(weekEvents.count)")
                StatChip(symbol: "note.text", text: "\(weekNotes.count)")
                StatChip(symbol: "checklist", text: todos.isEmpty ? "0/0" : "\(todosDone)/\(todos.count)")
            }
            EmptyView()
        }
    }
}