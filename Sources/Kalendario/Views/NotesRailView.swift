import SwiftUI

struct StickyNoteCardView: View {
    @Environment(DataStore.self) private var store

    let noteID: UUID
    let weekStart: Date

    @FocusState private var draftFocused: Bool

    private var app: AppState { AppState.shared }
    private var hoverKey: String { "note-\(noteID.uuidString)" }
    private var hovering: Bool { app.isHovered(hoverKey) }
    private var draftTodo: String { app.todoDraft(for: noteID) }

    var body: some View {
        @Bindable var store = store
        if let index = store.notes.firstIndex(where: { $0.id == noteID }) {
            card(note: $store.notes[index], value: store.notes[index])
        }
    }

    private func card(note: Binding<StickyNote>, value: StickyNote) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            header(note: note, value: value)

            if !value.todos.isEmpty {
                todos(note: note, value: value)
                progress(value: value)
            }

            addTodoRow(note: note, value: value)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(value.color.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(value.color.edge.opacity(0.35), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(value.color.edge.opacity(0.85))
                .frame(height: 3)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
        }
        .shadow(color: .black.opacity(0.10), radius: 7, x: 0, y: 3)
        .onHover { app.setHovered(hoverKey, $0) }
    }

    private func header(note: Binding<StickyNote>, value: StickyNote) -> some View {
        HStack(spacing: 7) {
            Circle().fill(value.color.edge).frame(width: 9, height: 9)

            InlineField(text: note.title,
                        placeholder: "Title",
                        font: .system(size: 13, weight: .semibold, design: .rounded),
                        color: value.color.ink)

            Spacer(minLength: 0)

            Menu {
                Section("Color") {
                    ForEach(NoteColor.allCases) { color in
                        Button {
                            note.wrappedValue.color = color
                        } label: {
                            Label(color.label, systemImage: value.color == color ? "circle.fill" : "circle")
                        }
                    }
                }
                Section {
                    Button("Duplicate") { store.duplicateNote(id: value.id) }
                    Button("Move to next week") {
                        store.moveNote(id: value.id, toWeek: WeekMath.addWeeks(1, to: weekStart))
                    }
                    Button("Move to previous week") {
                        store.moveNote(id: value.id, toWeek: WeekMath.addWeeks(-1, to: weekStart))
                    }
                }
                Section {
                    Button("Delete sticky note", role: .destructive) { store.deleteNote(id: value.id) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(value.color.ink.opacity(0.65))
                    .frame(width: 20, height: 18)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func todos(note: Binding<StickyNote>, value: StickyNote) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(value.todos.enumerated()), id: \.element.id) { entry in
                todoRow(note: note, value: value, index: entry.offset, todo: entry.element)
            }
        }
    }

    private func todoRow(note: Binding<StickyNote>, value: StickyNote, index: Int, todo: TodoItem) -> some View {
        HStack(spacing: 7) {
            Button {
                store.toggleTodo(noteID: value.id, todoID: todo.id)
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12.5))
                    .foregroundStyle(todo.isDone ? value.color.edge : value.color.ink.opacity(0.4))
            }
            .buttonStyle(.plain)

            InlineField(text: note.todos[index].text,
                        placeholder: "Task",
                        font: .system(size: 12.5),
                        color: todo.isDone ? value.color.ink.opacity(0.55) : value.color.ink,
                        strikethrough: todo.isDone)

            Spacer(minLength: 0)

            Button {
                store.deleteTodo(noteID: value.id, todoID: todo.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(value.color.ink.opacity(0.4))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0.25)
            .help("Remove task")
        }
    }

    private func progress(value: StickyNote) -> some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(value.color.ink.opacity(0.14))
                    Capsule()
                        .fill(value.color.edge)
                        .frame(width: max(2, geometry.size.width * value.progress))
                }
            }
            .frame(height: 4)

            Text("\(value.doneCount)/\(value.todos.count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value.color.ink.opacity(0.7))
        }
        .padding(.top, 1)
    }

    private func addTodoRow(note: Binding<StickyNote>, value: StickyNote) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(value.color.ink.opacity(0.45))
                .frame(width: 12)

            InlineField(text: Binding(
                get: { draftTodo },
                set: { app.setTodoDraft($0, for: noteID) }
            ),
                        placeholder: "Add a task…",
                        font: .system(size: 12),
                        color: value.color.ink)
                .focused($draftFocused)
                .onSubmit(commitDraft)

            if !draftTodo.isEmpty {
                Button(action: commitDraft) {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(value.color.edge))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commitDraft() {
        app.commitTodoDraft(for: noteID)
    }
}