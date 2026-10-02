import SwiftUI

/// The week's sticky notes, in a dedicated horizontal panel under the calendar.
/// Title, week number and the add button live *inside* the panel at the top left: there is no
/// header band and no separator above the cards.
struct NotesStripView: View {
    @Environment(DataStore.self) private var store

    let weekStart: Date

    var body: some View {
        let weekNotes = store.notes(inWeek: weekStart)

        HStack(alignment: .top, spacing: 12) {
            titleBlock

            HStack(alignment: .top, spacing: 12) {
                ForEach(weekNotes) { note in
                    StickyNoteCardView(noteID: note.id, weekStart: weekStart)
                        .frame(width: 268)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rowScroll()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(height: 228)
        .background(Theme.paperElevated.opacity(0.25))
    }

    private var titleBlock: some View {
        let weekNotes = store.notes(inWeek: weekStart)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .semibold))
                Text("Sticky notes")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.inkSoft)

            Text("Week \(WeekMath.weekNumber(weekStart))")
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkFaint)

            Button {
                store.addNote(inWeek: weekStart)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                    Text("New").font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.accent.opacity(0.10)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("New sticky note (⇧⌘N)")

            if weekNotes.isEmpty {
                Text("None this week")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 128, alignment: .leading)
    }
}