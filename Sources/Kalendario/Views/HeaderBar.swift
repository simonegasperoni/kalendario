import SwiftUI

struct HeaderBar: View {
    @Environment(DataStore.self) private var store

    private var weekStart: Date { AppState.shared.weekStart }

    var body: some View {
        HStack(spacing: 14) {
            brand
            weekNavigator
            Spacer(minLength: 8)
            weatherChip
            HStack(spacing: 8) {
                Button { AppState.shared.newEventInCurrentWeek() } label: {
                    Label("Event", systemImage: "plus")
                }
                .buttonStyle(PillButtonStyle(kind: .primary))

                Button { AppState.shared.newNote() } label: {
                    Label("Sticky note", systemImage: "note.text")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))

                Button { AppState.shared.openIssueImport() } label: {
                    Label("Issues", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .help("Import issues from a GitHub repository")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.paperElevated.opacity(0.55))
    }

    private var brand: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(hex: "#0A0A0A"))
                Text("K")
                    .font(.custom("TimesNewRomanPS-BoldMT", size: 17).weight(.bold))
                    .foregroundStyle(.white)
                    .offset(y: 0.5)
            }
            .frame(width: 26, height: 26)

            Text("Kalendario")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ink)
        }
    }

    private var weekNavigator: some View {
        HStack(spacing: 8) {
            IconButton(symbol: "chevron.left", help: "Previous week (⌘←)") {
                AppState.shared.previousWeek()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(DateText.weekTitle(weekStart))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                Text("\(store.events(inWeek: weekStart).count) events this week")
                    .font(Theme.tinyFont)
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }
            .frame(minWidth: 232, alignment: .leading)

            IconButton(symbol: "chevron.right", help: "Next week (⌘→)") {
                AppState.shared.nextWeek()
            }

            Button {
                AppState.shared.goToToday()
            } label: {
                Text("Today")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.ink.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Back to the current week (⌘T)")
        }
    }

    /// Shows the place the forecast refers to, and opens the weather settings.
    private var weatherChip: some View {
        let weather = AppState.shared.weather
        let full = weather.hasPlace ? weather.placeName : "Set weather place"
        let shown = full.count > 18 ? String(full.prefix(17)) + "…" : full

        return Button {
            AppState.shared.showWeatherPlace = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                Text(shown)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.ink.opacity(0.055), in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help("Weather settings — place: \(full)")
    }

    private var stats: some View {
        let weekEvents = store.events(inWeek: weekStart)
        let done = weekEvents.filter { $0.isCompleted }.count
        let weekNotes = store.notes(inWeek: weekStart)
        let todos = weekNotes.flatMap { $0.todos }
        let todosDone = todos.filter { $0.isDone }.count

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                StatChip(symbol: "calendar", text: "\(weekEvents.count) events")
                StatChip(symbol: "checkmark.circle", text: "\(done) done")
                StatChip(symbol: "note.text", text: "\(weekNotes.count) sticky notes")
                StatChip(symbol: "checklist", text: todos.isEmpty ? "0/0" : "\(todosDone)/\(todos.count)")
            }
            HStack(spacing: 6) {
                StatChip(symbol: "calendar", text: "\(weekEvents.count)")
                StatChip(symbol: "checklist", text: todos.isEmpty ? "0/0" : "\(todosDone)/\(todos.count)")
            }
            EmptyView()
        }
    }
}