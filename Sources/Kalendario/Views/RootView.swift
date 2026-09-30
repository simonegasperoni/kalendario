import SwiftUI

struct RootView: View {
    @Environment(DataStore.self) private var store
    private let app = AppState.shared

    var body: some View {
        let editor = app.editor
        let showIssues = app.showIssueImport

        VStack(spacing: 0) {
            HeaderBar()
                .sheet(isPresented: Binding(get: { showIssues }, set: { app.showIssueImport = $0 })) {
                    IssueImportView(model: app.issueImport)
                }

            Separator()

            HStack(spacing: 0) {
                WeekGridView(weekStart: app.weekStart,
                             onCreateEvent: { day, hour in app.newEvent(day: day, hour: hour) },
                             onEditEvent: { event in app.edit(event) })

                Separator(axis: .vertical)

                NotesRailView(weekStart: app.weekStart)
            }

            Separator()

            FooterView()
        }
        .background(Theme.paper)
        .sheet(item: Binding(get: { editor }, set: { app.editor = $0 })) { draft in
            EventEditorView(draft: draft)
                .environment(store)
        }
        .onChange(of: store.events) { _, _ in store.scheduleSave() }
        .onChange(of: store.notes) { _, _ in store.scheduleSave() }
        .onChange(of: store.locations) { _, _ in store.scheduleSave() }
        .onChange(of: store.assignments) { _, _ in store.scheduleSave() }
    }
}

struct FooterView: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(EventCategory.allCases) { category in
                HStack(spacing: 5) {
                    Circle().fill(category.color).frame(width: 7, height: 7)
                    Text(category.label).font(.system(size: 11))
                }
                .foregroundStyle(Theme.inkSoft)
            }

            Spacer(minLength: 12)

            ViewThatFits(in: .horizontal) {
                hint("Click an empty slot to create an event · ⌘N new event · ⌘T back to today")
                hint("⌘N new event · ⌘T today")
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 32)
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