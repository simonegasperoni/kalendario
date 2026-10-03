import SwiftUI

struct WeekGridView: View {
    @Environment(DataStore.self) private var store

    let weekStart: Date
    var onCreateEvent: (Date, Int) -> Void
    var onEditEvent: (CalendarEvent) -> Void

    var body: some View {
        let days = WeekMath.daysInWeek(from: weekStart)

        VStack(spacing: 0) {
            header(days: days)

            Separator()

            // One list of events per day; each column scrolls on its own.
            HStack(alignment: .top, spacing: 0) {
                ForEach(days, id: \.self) { day in
                    DayColumnView(day: day,
                                  onCreate: { onCreateEvent(day, AppState.shared.defaultHour) },
                                  onEditEvent: onEditEvent)
                        // Without this the column is a ScrollView, which is not greedy: the stack
                        // would give it the width its content asks for, so a day with longer
                        // texts came out wider than the others.
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)

            Separator()

            // One round "add an event" button per day, in a row of its own under the columns: inside
            // the column it ended up sitting on the temperatures of the forecast.
            AddEventRow(days: days,
                        onCreate: { day in onCreateEvent(day, AppState.shared.defaultHour) })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(days: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                DayHeaderCell(day: day)
            }
        }
        .padding(.vertical, 4)
        // Moved here with the places: the row that holds them is the header row itself now.
        .sheet(isPresented: Binding(get: { AppState.shared.showLocations },
                                    set: { AppState.shared.showLocations = $0 })) {
            WorkLocationsView()
                .environment(store)
        }
    }
}

/// One round "add an event" button per day, in a row of its own under the columns. Inside the column
/// the button ended up sitting on the temperatures of the forecast, and in a full day under the fold.
struct AddEventRow: View {
    let days: [Date]
    var onCreate: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                AddEventCell(day: day, onCreate: { onCreate(day) })
            }
        }
        .padding(.vertical, 5)
    }
}

/// The round button of one day. The disc is small; the whole cell is clickable, so the target is
/// generous, and it is the same on every day.
struct AddEventCell: View {
    let day: Date
    var onCreate: () -> Void

    private let app = AppState.shared

    private var key: String { "add-\(WeekMath.dayKey(day))" }

    var body: some View {
        Button(action: onCreate) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(app.isHovered(key) ? Theme.accentStrong : Theme.accent))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .onHover { app.setHovered(key, $0) }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.hairline).frame(width: 1)
        }
        .help("New event on \(DateText.dayTitle(day))")
    }
}

/// One day of the merged header: date and weekday, the small forecast icon and the place you work
/// from, all in the same cell. The forecast used to live on its own row and the places on another.
struct DayHeaderCell: View {
    @Environment(DataStore.self) private var store

    let day: Date

    private let app = AppState.shared

    var body: some View {
        let today = WeekMath.isToday(day)
        let forecast = app.weather.forecast(on: day)

        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text("\(DateText.dayNumber.string(from: day)) \(DateText.monthShort.string(from: day))")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(today ? Theme.accent : Theme.ink)

                Text(DateText.weekdayTitle(day).uppercased())
                    .font(.system(size: 8.5, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(today ? Theme.accent : Theme.inkSoft)

                if let forecast {
                    Image(systemName: forecast.symbol)
                        .font(.system(size: 11))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.accentStrong)
                        .help("\(forecast.summary) · max \(forecast.maximumText) · min \(forecast.minimumText)")
                }
            }
            .lineLimit(1)

            WorkLocationCell(day: day)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(dropBackground)
        .dropDestination(for: String.self) { items, _ in
            // Only an event belongs here: a sticky note dragged from the panel is not accepted.
            guard let text = items.first, let id = UUID(uuidString: text),
                  store.eventIndex(of: id) != nil else { return false }
            store.move(eventID: id, toDay: day)
            return true
        } isTargeted: { targeted in
            app.setHovered("drop-\(WeekMath.dayKey(day))", targeted)
        }
    }

    /// Cell highlight while an activity is dragged over the cell; the table itself is transparent.
    private var dropBackground: Color {
        app.isHovered("drop-\(WeekMath.dayKey(day))") ? Theme.accent.opacity(0.12) : Color.clear
    }
}

