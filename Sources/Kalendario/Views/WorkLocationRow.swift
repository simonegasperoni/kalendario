import SwiftUI

/// The coloured place chip of one day. Tapping it opens the picker popover.
/// The chip is a plain view on purpose: a `Menu` label would not stretch to the column width.
struct WorkLocationCell: View {
    @Environment(DataStore.self) private var store

    let day: Date

    private let app = AppState.shared

    private var dayKey: String { WeekMath.dayKey(day) }

    var body: some View {
        let assigned = store.location(on: day)
        let isOpen = app.locationPickerDay == dayKey

        chip(for: assigned)
            .padding(.horizontal, 3)
            .contentShape(Rectangle())
            .onTapGesture {
                app.locationPickerDay = isOpen ? nil : dayKey
            }
            .popover(isPresented: Binding(
                get: { isOpen },
                set: { app.locationPickerDay = $0 ? dayKey : nil }
            ), arrowEdge: .bottom) {
                WorkLocationPicker(day: day)
                    .environment(store)
            }
            .help(assigned == nil
                  ? "Choose where you work on \(DateText.weekdayTitle(day))"
                  : "\(assigned?.displayName ?? "") — click to change")
    }

    @ViewBuilder
    private func chip(for location: WorkLocation?) -> some View {
        if let location {
            Text(location.displayName)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(location.color.tagText)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(location.color.tagFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
        } else {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                Text("Where?")
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.inkFaint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            )
        }
    }
}

/// Popover content: pick a place, create one, manage them or clear the day.
struct WorkLocationPicker: View {
    @Environment(DataStore.self) private var store

    let day: Date

    private let app = AppState.shared

    var body: some View {
        let assigned = store.location(on: day)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(DateText.weekdayTitle(day))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Where do you work?")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Separator()

            if store.locations.isEmpty {
                Text("No places yet: create the first one below.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.locations) { location in
                    placeRow(location, selected: assigned?.id == location.id)
                }
            }

            Separator()

            actionRow("New place…", systemImage: "plus") {
                app.addLocationAndManage()
            }
            actionRow("Manage places…", systemImage: "slider.horizontal.3") {
                app.openLocations()
            }
            if assigned != nil {
                actionRow("Clear this day", systemImage: "xmark") {
                    store.assignLocation(nil, to: day)
                    app.locationPickerDay = nil
                }
            }
        }
        .frame(width: 230)
        .background(Theme.paper)
    }

    private func placeRow(_ location: WorkLocation, selected: Bool) -> some View {
        Button {
            store.assignLocation(location.id, to: day)
            app.locationPickerDay = nil
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(location.color.tagFill)
                    .frame(width: 9, height: 9)
                Text(location.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 9)
                Text(title)
                    .font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}