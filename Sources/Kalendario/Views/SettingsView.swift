import SwiftUI

/// One place for the settings: the weather place, the GitHub token and a way into the work places.
/// Opened by the gear in the top bar, and with ⌘, from the menu.
struct SettingsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.kalendarioPreview) private var preview

    private let app = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Separator()

            VerticalFlow {
                VStack(alignment: .leading, spacing: 16) {
                    WeatherPlaceField(model: app.weather)
                    GitHubTokenField(model: app.issueImport)
                    GitHubRepositoriesField(model: app.repoMeta)
                    placesField
                }
                .padding(20)
            }

            Separator()
            footer
        }
        .frame(width: preview ? nil : 520, height: preview ? nil : 700)
        .background(Theme.paper)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("Weather, GitHub and work places, all in one place.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            IconButton(symbol: "xmark", help: "Close") { app.showSettings = false }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.paperElevated.opacity(0.6))
    }

    private var placesField: some View {
        FieldBox(title: "Work places") {
            VStack(alignment: .leading, spacing: 8) {
                if store.locations.isEmpty {
                    Text("No places yet. Add Home, the offices you use, a client site…")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // One place per line, like the repositories above: a row of chips would grow
                    // past the edge of the window as soon as the names get long.
                    VStack(spacing: 4) {
                        ForEach(store.locations) { location in
                            placeRow(location)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button("Add a place") { store.addLocation() }
                        .buttonStyle(PillButtonStyle(kind: .secondary))

                    Button("Edit work places…") {
                        app.showSettings = false
                        app.openLocations()
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary))

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func placeRow(_ location: WorkLocation) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(location.color.tagFill)
                .frame(width: 9, height: 9)

            Text(location.displayName)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            Text(location.color.label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.paperElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { app.showSettings = false }
                .buttonStyle(PillButtonStyle(kind: .primary))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.paperElevated.opacity(0.4))
    }
}

/// The repositories the commit row reads. Writing one here is enough: it does not have to be
/// imported first, because the commits and the issues are two independent things.
struct GitHubRepositoriesField: View {
    @Bindable var model: RepoMetaModel

    @Environment(DataStore.self) private var store
    @FocusState private var focused: Bool

    var body: some View {
        FieldBox(title: "GitHub repositories") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("owner/name", text: $model.newRepository)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .fieldChrome()
                        .focused($focused)
                        .onSubmit(add)

                    Button("Add", action: add)
                        .buttonStyle(PillButtonStyle(kind: .primary))
                        .disabled(!model.canAddRepository)
                }

                if !model.configured.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(model.configured, id: \.self) { name in
                            row(name)
                        }
                    }
                }

                if !store.importedRepositories.isEmpty {
                    Text("Read as well, because their issues are on the calendar: \(store.importedRepositories.joined(separator: ", ")).")
                        .font(Theme.tinyFont)
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("The row at the foot of the calendar shows the commits of these repositories, one cell per day, even if no issue ever came from them.")
                    .font(Theme.tinyFont)
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)

            Text(name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                model.removeRepository(name)
                AppState.shared.refreshRepoMeta()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Stop reading this repository")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.paperElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func add() {
        guard model.addRepository(model.newRepository) else { return }
        model.newRepository = ""
        // The row at the foot of the calendar reads it straight away.
        AppState.shared.refreshRepoMeta()
    }
}

/// The weather place: the same field in the settings and in the weather sheet.
struct WeatherPlaceField: View {
    @Bindable var model: WeatherModel

    private let app = AppState.shared

    var body: some View {
        FieldBox(title: "Weather place") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TextField("City, e.g. Milano", text: $model.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                        .fieldChrome()
                        .onSubmit { model.search() }

                    Button("Set") { model.search() }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                        .disabled(model.isLoading || model.query.isEmpty)
                }

                if model.hasPlace {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10, weight: .semibold))
                        Text(model.placeName).font(.system(size: 11.5))
                        Spacer()
                        Button("Refresh") { model.load() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .disabled(model.isLoading)
                    }
                    .foregroundStyle(Theme.inkSoft)
                }

                if model.isLoading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Loading the forecast…")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }

                if !model.status.isEmpty {
                    Text(model.status)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accentSoft,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Text("The name is searched in your system language and in Italian. Forecast from Open-Meteo.com, refreshed every 30 minutes.")
                    .font(Theme.tinyFont)
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The GitHub token: the same field in the settings and in the import sheet, together with the
/// permissions it needs — issues are read with `Issues: read`, the commit counts of the row under the
/// calendar with `Contents: read` (a classic token needs the `repo` scope).
struct GitHubTokenField: View {
    @Bindable var model: IssueImportModel

    var body: some View {
        FieldBox(title: "GitHub access token") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    SecureField("ghp_… (optional)", text: $model.tokenInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .fieldChrome()

                    Button("Save") {
                        model.saveToken()
                        // The row at the foot of the calendar reads again straight away, with the
                        // token just stored.
                        AppState.shared.refreshRepoMeta()
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .disabled(model.tokenInput.isEmpty)

                    if model.hasStoredToken {
                        Button("Remove") { model.clearToken() }
                            .buttonStyle(PillButtonStyle(kind: .secondary))
                    }
                }

                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: model.hasStoredToken ? "checkmark.seal.fill" : "info.circle")
                        .font(.system(size: 10))
                    Text(model.hasStoredToken
                         ? "A token is stored in the macOS Keychain. It is never written to your calendar file."
                         : "Without a token only public repositories work, with a 60 requests/hour limit.")
                        .font(Theme.tinyFont)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.inkFaint)

                Text("Permissions: Issues: read to import issues, Contents: read for the commit counts (a classic token needs the repo scope).")
                    .font(Theme.tinyFont)
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}