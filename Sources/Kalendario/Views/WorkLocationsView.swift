import SwiftUI

/// Manages the customisable "where I work" tags: one name and one colour per place.
struct WorkLocationsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.kalendarioPreview) private var preview

    private let app = AppState.shared

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 0) {
            header
            Separator()

            VerticalFlow {
                VStack(alignment: .leading, spacing: 14) {
                    if store.locations.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(store.locations.enumerated()), id: \.element.id) { entry in
                            row(value: entry.element, location: $store.locations[entry.offset])
                            if entry.offset < store.locations.count - 1 { Separator() }
                        }
                    }

                    addButton
                    hint
                }
                .padding(18)
            }

            Separator()
            footer
        }
        .frame(width: preview ? nil : 480, height: preview ? nil : 560)
        .background(Theme.paper)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Work places")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("One tag per place, with its own colour, so the week shows at a glance where you work.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            IconButton(symbol: "xmark", help: "Close") { app.showLocations = false }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.paperElevated.opacity(0.6))
    }

    private func row(value: WorkLocation, location: Binding<WorkLocation>) -> some View {
        HStack(spacing: 9) {
            HStack(spacing: 3) {
                ForEach(NoteColor.allCases) { color in
                    Button {
                        location.wrappedValue.color = color
                    } label: {
                        Circle()
                            .fill(color.tagFill)
                            .frame(width: 13, height: 13)
                            .padding(2)
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.ink.opacity(value.color == color ? 0.7 : 0),
                                                  lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(color.label)
                }
            }

            InlineField(text: location.name,
                        placeholder: "Home, Office, Client site…",
                        font: .system(size: 12.5),
                        color: Theme.ink)
                .fieldChrome()

            IconButton(symbol: "trash", help: "Delete this place") {
                store.deleteLocation(id: value.id)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.inkFaint)
            Text("No places yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
            Text("Add Home, the offices you use, a client site… then pick one for each day.")
                .font(Theme.tinyFont)
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    private var addButton: some View {
        Button {
            store.addLocation()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                Text("Add a place").font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(Theme.accent)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accent.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
    }

    private var hint: some View {
        Text("You can also pick a place day by day from the PLACE row under the day names, and clear a day with “Clear this day”.")
            .font(Theme.tinyFont)
            .foregroundStyle(Theme.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Text("\(store.locations.count) place\(store.locations.count == 1 ? "" : "s")")
                .font(Theme.tinyFont)
                .foregroundStyle(Theme.inkFaint)
            Spacer()
            Button("Done") { app.showLocations = false }
                .buttonStyle(PillButtonStyle(kind: .primary))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.paperElevated.opacity(0.4))
    }
}