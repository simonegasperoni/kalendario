import SwiftUI

/// One day of the week as a list of its events: no timeline, latest first.
/// The column itself is transparent and accepts an event dragged from another day.
struct DayColumnView: View {
    @Environment(DataStore.self) private var store

    let day: Date
    var onCreate: () -> Void
    var onEditEvent: (CalendarEvent) -> Void

    private let app = AppState.shared

    private var dayKey: String { WeekMath.dayKey(day) }

    var body: some View {
        let events = store.events(on: day)
        let isToday = WeekMath.isToday(day)

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                // Full-day activities first: they belong to the whole day, not to a time.
                ForEach(store.allDayEvents(on: day)) { activity in
                    EventBlockView(event: activity, onEdit: onEditEvent)
                        .draggable(activity.id.uuidString)
                }

                ForEach(events) { event in
                    EventBlockView(event: event, onEdit: onEditEvent)
                        .draggable(event.id.uuidString)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .top)
            .columnScroll()
            .frame(maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .background(app.isHovered("drop-\(dayKey)") ? Theme.accent.opacity(0.10) : Color.clear)
        // The forecast is the backdrop of the day on every column: same superimposition behind the
        // events, only the colour changes — paperShade on the paper, a darker celeste on today's
        // slate. The user asked for exactly this consistency on 2026-10-04. It goes *before* the dark
        // fill of today, which is opaque: drawn after, it would hide the forecast completely.
        .background(alignment: .bottom) { weatherWatermark(isToday: isToday) }
        .background(isToday ? Theme.todayColumn : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.hairline).frame(width: 1)
        }
        .dropDestination(for: String.self) { items, _ in
            // Only an event belongs here: a sticky note dragged from the panel is not accepted.
            guard let text = items.first, let id = UUID(uuidString: text),
                  store.eventIndex(of: id) != nil else { return false }
            store.move(eventID: id, toDay: day)
            return true
        } isTargeted: { targeted in
            app.setHovered("drop-\(dayKey)", targeted)
        }
    }

    /// The forecast of the day at the foot of the column: the icon big and quiet — the same tone as the
    /// paper, a little darker — with the temperatures under it, in a colour that reads. On the dark
    /// column of today the two are inverted: the icon is *lighter* than the background under it.
    /// The icon is a fixed size (about half the width of a column): widening the window must not make
    /// it grow.
    @ViewBuilder
    private func weatherWatermark(isToday: Bool) -> some View {
        if let forecast = app.weather.forecast(on: day) {
            VStack(spacing: 1) {
                Image(systemName: forecast.symbol)
                    .font(.system(size: 80))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isToday ? Theme.todayColumnIcon : Theme.paperShade)

                Text("\(forecast.maximumText)/\(forecast.minimumText)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Theme.todayColumnText : Theme.inkSoft)
            }
            .padding(.bottom, 2)
            .help("\(forecast.summary) · max \(forecast.maximumText) · min \(forecast.minimumText)")
        }
    }
}

/// One event as a card: category colour, left bar, time range, title, notes and the completed
/// state. It takes the height of its content, so the day reads as a list.
struct EventBlockView: View {
    let event: CalendarEvent
    var onEdit: (CalendarEvent) -> Void

    private var key: String { "event-\(event.id.uuidString)" }
    private var app: AppState { AppState.shared }
    private var hovering: Bool { app.isHovered(key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: event.category.symbol)
                    .font(.system(size: 8.5, weight: .semibold))
                Text(event.isAllDay ? "FULL DAY" : event.timeRange)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if event.isCompleted {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(event.category.color)

            Text(event.displayTitle)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .strikethrough(event.isCompleted, color: Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if !event.notes.isEmpty {
                Text(event.notes)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(event.category.color.opacity(event.isCompleted ? 0.08 : 0.14))
        )
        // An opaque paper base under the tint: the card keeps its colour on the dark column of today
        // instead of becoming a dark patch, and on the paper columns nothing changes.
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.paper)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.category.color.opacity(event.isCompleted ? 0.45 : 1))
                .frame(width: 3)
                .padding(.vertical, 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(event.category.color.opacity(hovering ? 0.55 : 0.22), lineWidth: 1)
        }
        .opacity(event.isCompleted ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onTapGesture { onEdit(event) }
        .onHover { app.setHovered(key, $0) }
        .help("\(event.displayTitle) · \(event.timeRange) — click to edit, drag to another day")
    }
}