import SwiftUI

struct EventEditorView: View {
    @Bindable var draft: EventDraft

    @FocusState private var titleFocused: Bool

    private let presetDurations = [15, 30, 45, 60, 90, 120, 180, 240]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Separator()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleField
                    categoryField
                    dayField
                    timeField
                    durationField
                    completionField
                    notesField
                }
                .padding(20)
            }

            Separator()
            footer
        }
        .frame(width: 470, height: 590)
        .background(Theme.paper)
        .onAppear {
            if draft.event.title.isEmpty { titleFocused = true }
        }
    }

    private var isNew: Bool { draft.isNew }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isNew ? "New event" : "Edit event")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("\(DateText.relativeDay(draft.event.start)) · \(draft.event.timeRange)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
                    .monospacedDigit()
            }
            Spacer()
            Circle().fill(draft.event.category.color).frame(width: 11, height: 11)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.paperElevated.opacity(0.6))
    }

    private var titleField: some View {
        FieldBox(title: "Title") {
            TextField("e.g. Weekly meeting", text: $draft.event.title)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
                .focused($titleFocused)
                .fieldChrome()
        }
    }

    private var categoryField: some View {
        FieldBox(title: "Category") {
            HStack(spacing: 6) {
                ForEach(EventCategory.allCases) { category in
                    let selected = draft.event.category == category
                    Button {
                        draft.event.category = category
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(selected ? Color.white : category.color).frame(width: 7, height: 7)
                            Text(category.label).font(.system(size: 11.5, weight: .medium))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .foregroundStyle(selected ? Color.white : Theme.ink)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? category.color : Theme.ink.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dayField: some View {
        FieldBox(title: "Day") {
            let monday = WeekMath.startOfWeek(draft.event.start)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(WeekMath.daysInWeek(from: monday), id: \.self) { day in
                        let selected = WeekMath.isSameDay(day, draft.event.start)
                        Button {
                            draft.event.start = WeekMath.combine(day: day, time: draft.event.start)
                        } label: {
                            VStack(spacing: 1) {
                                Text(DateText.weekdayTitle(day)).font(.system(size: 9, weight: .semibold))
                                Text(DateText.dayNumber.string(from: day))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .foregroundStyle(selected ? Color.white : Theme.ink)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected ? Theme.accent : Theme.ink.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    Text(DateText.relativeDay(draft.event.start))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    DatePicker("", selection: dayBinding, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
            }
        }
    }

    private var timeField: some View {
        FieldBox(title: "Start") {
            VStack(alignment: .leading, spacing: 8) {
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)

                HStack(spacing: 5) {
                    ForEach([8, 10, 12, 14, 16, 18], id: \.self) { hour in
                        Button("\(WeekMath.hourLabel(hour)):00") {
                            draft.event.start = WeekMath.combine(
                                day: draft.event.start,
                                time: WeekMath.makeDate(day: draft.event.start, hour: hour)
                            )
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Theme.inkSoft)
                        .background(Theme.ink.opacity(0.06), in: Capsule())
                    }
                    Spacer()
                }
            }
        }
    }

    private var durationField: some View {
        FieldBox(title: "Duration") {
            HStack(spacing: 10) {
                Picker("", selection: durationBinding) {
                    ForEach(presetDurations, id: \.self) { minutes in
                        Text(WeekMath.durationLabel(minutes)).tag(minutes)
                    }
                    Text("Custom").tag(-1)
                }
                .labelsHidden()
                .frame(width: 170)

                if isCustomDuration {
                    Stepper(value: $draft.event.durationMinutes, in: 5...600, step: 5) {
                        Text(WeekMath.durationLabel(draft.event.durationMinutes))
                            .font(.system(size: 12))
                            .monospacedDigit()
                    }
                } else {
                    Text("until \(DateText.hourMinute.string(from: draft.event.end))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.inkFaint)
                        .monospacedDigit()
                }

                Spacer()
            }
        }
    }

    private var completionField: some View {
        Toggle(isOn: $draft.event.isCompleted) {
            Text("Mark as completed").font(.system(size: 12.5))
        }
        .toggleStyle(.switch)
        .tint(Theme.accent)
    }

    private var notesField: some View {
        FieldBox(title: "Notes") {
            TextEditor(text: $draft.event.notes)
                .font(.system(size: 12.5))
                .scrollContentBackground(.hidden)
                .frame(height: 68)
                .padding(6)
                .background(Theme.paperElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if !isNew {
                Button(role: .destructive) {
                    AppState.shared.store.delete(eventID: draft.event.id)
                    AppState.shared.editor = nil
                } label: {
                    Label("Delete", systemImage: "trash").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
            }

            Spacer()

            Button("Cancel") { AppState.shared.cancelEditor() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(Theme.inkSoft)

            Button("Save") { AppState.shared.saveEditor() }
                .buttonStyle(PillButtonStyle(kind: .primary))
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Derived bindings

    private var isCustomDuration: Bool {
        !presetDurations.contains(draft.event.durationMinutes)
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: { draft.event.start },
            set: { draft.event.start = WeekMath.combine(day: $0, time: draft.event.start) }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { draft.event.start },
            set: { draft.event.start = WeekMath.combine(day: draft.event.start, time: $0) }
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { presetDurations.contains(draft.event.durationMinutes) ? draft.event.durationMinutes : -1 },
            set: { value in
                if value == -1 {
                    draft.event.durationMinutes = 75
                } else {
                    draft.event.durationMinutes = value
                }
            }
        )
    }
}