import SwiftUI

struct PlannedEvent: Identifiable {
    let event: CalendarEvent
    let lane: Int
    let lanes: Int

    var id: UUID { event.id }
    var widthFraction: CGFloat { 1 / CGFloat(max(1, lanes)) }
    var xFraction: CGFloat { CGFloat(lane) / CGFloat(max(1, lanes)) }
}

enum EventLayoutPlanner {
    static func plan(_ events: [CalendarEvent]) -> [PlannedEvent] {
        var result: [PlannedEvent] = []
        var cluster: [CalendarEvent] = []
        var clusterEnd: Date = .distantPast

        func flush() {
            guard !cluster.isEmpty else { return }
            var laneEnds: [Date] = []
            var assigned: [(CalendarEvent, Int)] = []

            for event in cluster {
                if let lane = laneEnds.firstIndex(where: { $0 <= event.start }) {
                    laneEnds[lane] = event.end
                    assigned.append((event, lane))
                } else {
                    laneEnds.append(event.end)
                    assigned.append((event, laneEnds.count - 1))
                }
            }

            let lanes = max(1, laneEnds.count)
            for (event, lane) in assigned {
                result.append(PlannedEvent(event: event, lane: lane, lanes: lanes))
            }

            cluster = []
            clusterEnd = .distantPast
        }

        for event in events.sorted(by: { $0.start < $1.start }) {
            if event.start >= clusterEnd { flush() }
            cluster.append(event)
            clusterEnd = max(clusterEnd, event.end)
        }
        flush()
        return result
    }
}

struct DayColumnView: View {
    @Environment(DataStore.self) private var store

    let day: Date
    let hourHeight: CGFloat
    var onCreate: (Int) -> Void
    var onEditEvent: (CalendarEvent) -> Void

    private var pxPerMinute: CGFloat { hourHeight / 60 }
    private var today: Bool { WeekMath.isToday(day) }
    private var weekend: Bool { WeekMath.isWeekend(day) }

    var body: some View {
        let planned = EventLayoutPlanner.plan(store.events(on: day))

        GeometryReader { geometry in
            let columnWidth = geometry.size.width

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        HourSlotView(hour: hour,
                                     hoverKey: "slot-\(day.timeIntervalSince1970)-\(hour)",
                                     onCreate: { onCreate(hour) })
                            .frame(height: hourHeight)
                    }
                }
                .frame(width: columnWidth)

                ForEach(planned) { item in
                    EventBlockView(event: item.event, onEdit: onEditEvent)
                        .frame(width: max(28, columnWidth * item.widthFraction - 6),
                               height: max(20, CGFloat(item.event.durationMinutes) * pxPerMinute - 4))
                        .offset(x: columnWidth * item.xFraction + 3,
                                y: CGFloat(WeekMath.minutesFromMidnight(item.event.start)) * pxPerMinute + 2)
                }

                if today {
                    TimelineView(.periodic(from: Date(), by: 60)) { context in
                        CurrentTimeMarker()
                            .frame(width: columnWidth)
                            .offset(y: CGFloat(WeekMath.minutesFromMidnight(context.date)) * pxPerMinute - 3)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(width: columnWidth, height: hourHeight * 24, alignment: .topLeading)
            .background(columnBackground)
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.hairline).frame(width: 1) }
        }
        .frame(height: hourHeight * 24)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var columnBackground: some View {
        if today {
            Theme.todayWash
        } else if weekend {
            Theme.weekendWash
        } else {
            Color.clear
        }
    }
}

struct HourSlotView: View {
    let hour: Int
    let hoverKey: String
    var onCreate: () -> Void

    private var app: AppState { AppState.shared }
    private var hovering: Bool { app.isHovered(hoverKey) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(hovering ? Theme.accent.opacity(0.07) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture(perform: onCreate)
                .onHover { app.setHovered(hoverKey, $0) }

            VStack(spacing: 0) {
                Rectangle().fill(Theme.hairline.opacity(0.85)).frame(height: 1)
                Spacer(minLength: 0)
                Rectangle().fill(Theme.hairline.opacity(0.4)).frame(height: 1)
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)

            if hovering {
                HStack(spacing: 3) {
                    Image(systemName: "plus").font(.system(size: 8, weight: .bold))
                    Text("\(WeekMath.hourLabel(hour)):00").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Theme.accentSoft, in: Capsule())
                .padding(.leading, 5)
                .padding(.top, 4)
                .allowsHitTesting(false)
            }
        }
        .help("New event at \(WeekMath.hourLabel(hour)):00")
    }
}

struct CurrentTimeMarker: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(Theme.accent).frame(width: 7, height: 7).offset(x: -3)
            Rectangle().fill(Theme.accent).frame(height: 1.5)
        }
        .frame(height: 7)
    }
}

struct EventBlockView: View {
    let event: CalendarEvent
    var onEdit: (CalendarEvent) -> Void

    private var key: String { "event-\(event.id.uuidString)" }
    private var app: AppState { AppState.shared }
    private var hovering: Bool { app.isHovered(key) }

    private var compact: Bool { event.durationMinutes <= 30 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 0 : 2) {
            HStack(spacing: 4) {
                Image(systemName: event.category.symbol)
                    .font(.system(size: 8.5, weight: .semibold))
                Text(event.timeRange)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if event.isCompleted {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(event.category.color)

            Text(event.displayTitle)
                .font(.system(size: compact ? 10 : 11.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .strikethrough(event.isCompleted, color: Theme.inkSoft)
                .lineLimit(compact ? 1 : 3)

            if !compact, !event.notes.isEmpty {
                Text(event.notes)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(event.category.color.opacity(event.isCompleted ? 0.08 : 0.14))
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
        .help("\(event.displayTitle) · \(event.timeRange) — click to edit")
    }
}