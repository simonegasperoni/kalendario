import SwiftUI

struct WeekGridView: View {
    @Environment(DataStore.self) private var store

    let weekStart: Date
    var onCreateEvent: (Date, Int) -> Void
    var onEditEvent: (CalendarEvent) -> Void

    static let hourHeight: CGFloat = 58
    private let gutterWidth: CGFloat = 64

    private var app: AppState { AppState.shared }

    var body: some View {
        let days = WeekMath.daysInWeek(from: weekStart)

        VStack(spacing: 0) {
            header(days: days)

            Separator()

            WorkLocationRow(days: days, gutterWidth: gutterWidth)

            Separator()

            ScrollViewReader { proxy in
                VerticalFlow {
                    HStack(alignment: .top, spacing: 0) {
                        TimeGutterView(hourHeight: Self.hourHeight, width: gutterWidth)

                        ForEach(days, id: \.self) { day in
                            DayColumnView(day: day,
                                          hourHeight: Self.hourHeight,
                                          onCreate: { hour in onCreateEvent(day, hour) },
                                          onEditEvent: onEditEvent)
                        }
                    }
                    .onAppear {
                        guard !app.didScroll else { return }
                        app.didScroll = true
                        DispatchQueue.main.async { proxy.scrollTo(7, anchor: .top) }
                    }
                }
            }
            .overlay {
                if store.events(inWeek: weekStart).isEmpty { emptyWeekHint }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyWeekHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 20, weight: .light))
            Text("No events this week")
                .font(.system(size: 12.5, weight: .semibold))
            Text("Click any empty slot to add one, or import your GitHub issues.")
                .font(Theme.tinyFont)
        }
        .foregroundStyle(Theme.inkSoft)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.paperElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .allowsHitTesting(false)
    }

    private func header(days: [Date]) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth, height: 1)

            ForEach(days, id: \.self) { day in
                DayHeaderCell(day: day)
            }
        }
        .padding(.vertical, 7)
        .background(Theme.paperElevated.opacity(0.4))
    }
}

struct DayHeaderCell: View {
    let day: Date

    var body: some View {
        let today = WeekMath.isToday(day)

        VStack(spacing: 3) {
            Text(DateText.weekdayTitle(day))
                .font(.system(size: 10.5, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(today ? Theme.accent : Theme.inkSoft)

            ZStack {
                if today {
                    Circle().fill(Theme.accent).frame(width: 27, height: 27)
                }
                Text(DateText.dayNumber.string(from: day))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(today ? Color.white : Theme.ink)
            }
            .frame(height: 27)

            Text(DateText.monthShort.string(from: day))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

struct TimeGutterView: View {
    let hourHeight: CGFloat
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                ZStack(alignment: .topTrailing) {
                    Color.clear
                    Text(WeekMath.hourLabel(hour))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.trailing, 9)
                        .offset(y: hour == 0 ? 2 : -6)
                }
                .frame(height: hourHeight)
                .id(hour)
            }
        }
        .frame(width: width)
        .background(Theme.paperElevated.opacity(0.35))
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.hairline).frame(width: 1) }
    }
}