import SwiftUI

/// Weather settings: shows the place in use and lets it be changed.
/// Reached from the gear in the day header and from the chip in the toolbar.
struct WeatherSettingsView: View {
    @Bindable var model: WeatherModel

    @FocusState private var queryFocused: Bool
    @Environment(\.kalendarioPreview) private var preview

    private let app = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weather settings")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text(model.hasPlace ? "Now showing \(model.placeName)" : "No place set yet")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                IconButton(symbol: "xmark", help: "Close") { app.showWeatherPlace = false }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.paperElevated.opacity(0.6))

            Separator()

            VStack(alignment: .leading, spacing: 12) {
                FieldBox(title: "Place") {
                    HStack(spacing: 8) {
                        TextField("City, e.g. Milano", text: $model.query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                            .fieldChrome()
                            .focused($queryFocused)
                            .onSubmit { model.search() }

                        Button("Set") { model.search() }
                            .buttonStyle(PillButtonStyle(kind: .primary))
                            .disabled(model.isLoading || model.query.isEmpty)
                    }
                }

                if model.hasPlace {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 10, weight: .semibold))
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
                        Text("Loading the forecast…").font(.system(size: 11.5)).foregroundStyle(Theme.inkSoft)
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
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Text("The name is searched in your system language and in Italian. Forecast from Open-Meteo.com, refreshed every 30 minutes.")
                    .font(Theme.tinyFont)
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)

            Spacer(minLength: 0)

            Separator()
            HStack {
                Spacer()
                Button("Done") { app.showWeatherPlace = false }
                    .buttonStyle(PillButtonStyle(kind: .primary))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.paperElevated.opacity(0.4))
        }
        .frame(width: preview ? nil : 460, height: preview ? nil : 380)
        .background(Theme.paper)
        .onAppear { queryFocused = true }
    }
}