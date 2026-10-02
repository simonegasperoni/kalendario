import Foundation
import Observation

/// Forecast for the configured place. Only the place is persisted; the forecast itself stays in
/// memory, because it is not part of the user's data file.
@Observable
final class WeatherModel {
    private enum Key {
        static let name = "kalendario.weatherPlace"
        static let latitude = "kalendario.weatherLatitude"
        static let longitude = "kalendario.weatherLongitude"
        static let updated = "kalendario.weatherUpdated"
    }

    var placeName: String
    var query: String = ""
    var forecasts: [DailyForecast] = []
    var status: String = ""
    var isLoading = false

    private var latitude: Double?
    private var longitude: Double?

    init() {
        let defaults = UserDefaults.standard
        placeName = defaults.string(forKey: Key.name) ?? ""
        latitude = defaults.object(forKey: Key.latitude) as? Double
        longitude = defaults.object(forKey: Key.longitude) as? Double
    }

    var hasPlace: Bool { latitude != nil && longitude != nil }

    func forecast(on day: Date) -> DailyForecast? {
        forecasts.first { WeekMath.isSameDay($0.day, day) }
    }

    /// Called when the window appears: refreshes only when the data is older than 30 minutes.
    func refreshIfStale() {
        guard hasPlace, !isLoading else { return }
        if let updated = UserDefaults.standard.object(forKey: Key.updated) as? Date,
           Date().timeIntervalSince(updated) < 1800,
           !forecasts.isEmpty {
            return
        }
        load()
    }

    func load() {
        guard hasPlace, !isLoading else { return }
        isLoading = true
        status = ""
        Task { @MainActor in
            await performLoad()
            isLoading = false
        }
    }

    /// Geocodes what was typed, keeps it as the current place and loads its forecast.
    func search() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            status = "Type a place first, for example “Milan”."
            return
        }

        isLoading = true
        status = ""
        Task { @MainActor in
            do {
                let place = try await WeatherClient.geocode(text)
                apply(place)
                status = "Place set to \(place.name)."
                await performLoad()
            } catch {
                status = Self.message(for: error)
            }
            isLoading = false
        }
    }

    private func performLoad() async {
        guard let latitude, let longitude else { return }
        do {
            forecasts = try await WeatherClient.forecast(latitude: latitude, longitude: longitude)
            UserDefaults.standard.set(Date(), forKey: Key.updated)
            if forecasts.isEmpty { status = "No forecast for this place." }
        } catch {
            status = Self.message(for: error)
        }
    }

    private func apply(_ place: WeatherPlace) {
        placeName = place.name
        latitude = place.latitude
        longitude = place.longitude
        query = ""

        let defaults = UserDefaults.standard
        defaults.set(place.name, forKey: Key.name)
        defaults.set(place.latitude, forKey: Key.latitude)
        defaults.set(place.longitude, forKey: Key.longitude)
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    /// Used by the static previews only, to look like a place already configured.
    func setPlaceForPreview(name: String, latitude: Double, longitude: Double) {
        placeName = name
        self.latitude = latitude
        self.longitude = longitude
    }
}