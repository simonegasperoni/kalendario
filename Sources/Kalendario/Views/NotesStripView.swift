import SwiftUI

/// The week's sticky notes, in a dedicated horizontal panel under the calendar.
struct NotesStripView: View {
    @Environment(DataStore.self) private var store

    let weekStart: Date

    var body: some View {
        let weekNotes = store.notes(inWeek: weekStart)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text("Sticky notes for the week")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text("Week \(WeekMath.weekNumber(weekStart))")
                    .font(Theme.tinyFont)
                    .foregroundStyle(Theme.inkFaint)

                Spacer(minLength: 8)

                if weekNotes.isEmpty {
                    Text("No sticky notes this week")
                        .font(Theme.tinyFont)
                        .foregroundStyle(Theme.inkFaint)
                }

                Button {
                    store.addNote(inWeek: weekStart)
                } label: {
                    Label("New sticky note", systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .help("New sticky note (⇧⌘N)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Separator()

            HStack(alignment: .top, spacing: 12) {
                ForEach(weekNotes) { note in
                    StickyNoteCardView(noteID: note.id, weekStart: weekStart)
                        .frame(width: 268)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rowScroll()
        }
        .frame(height: 240)
        .background(Theme.paperElevated.opacity(0.25))
    }
}