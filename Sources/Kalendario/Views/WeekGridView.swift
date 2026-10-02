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

            WorkLocationRow(days: days)

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(days: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                DayHeaderCell(day: day)
            }
        }
        .padding(.vertical, 5)
    }
}

struct DayHeaderCell: View {
    @Environment(DataStore.self) private var store

    let day: Date

    private let app = AppState.shared

    var body: some View {
        let today = WeekMath.isToday(day)
        let forecast = app.weather.forecast(on: day)

        VStack(spacing: 2) {
            Text("\(DateText.dayNumber.string(from: day)) \(DateText.monthShort.string(from: day))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(today ? Theme.accent : Theme.ink)

            Text(DateText.weekdayTitle(day).uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(today ? Theme.accent : Theme.inkSoft)

            if let forecast {
                HStack(spacing: 4) {
                    Image(systemName: forecast.symbol)
                        .font(.system(size: 15))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.accentStrong)
                    Text("\(forecast.maximumText)/\(forecast.minimumText)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }
                .help("\(forecast.summary) · max \(forecast.maximumText) · min \(forecast.minimumText)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(dropBackground)
        .dropDestination(for: String.self) { items, _ in
            guard let text = items.first, let id = UUID(uuidString: text) else { return false }
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

