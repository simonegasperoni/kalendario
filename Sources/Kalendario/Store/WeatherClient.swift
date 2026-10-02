import Foundation

/// One day of the forecast. Weather code is the WMO one used by Open-Meteo.
struct DailyForecast: Identifiable, Hashable {
    let day: Date
    let code: Int
    let maximum: Double
    let minimum: Double

    var id: Date { day }
    var symbol: String { WeatherSymbol.symbol(for: code) }
    var summary: String { WeatherSymbol.summary(for: code) }
    var maximumText: String { "\(Int(maximum.rounded()))°" }
    var minimumText: String { "\(Int(minimum.rounded()))°" }
}

enum WeatherSymbol {
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.max"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61: return "cloud.drizzle.fill"
        case 63: return "cloud.rain.fill"
        case 65: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81: return "cloud.rain.fill"
        case 82: return "cloud.heavyrain.fill"
        case 95: return "cloud.bolt.rain.fill"
        case 96, 99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }

    static func summary(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61: return "Light rain"
        case 63: return "Rain"
        case 65: return "Heavy rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81: return "Rain showers"
        case 82: return "Violent rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }
}

struct WeatherPlace: Hashable {
    var name: String
    var latitude: Double
    var longitude: Double
}

enum WeatherError: LocalizedError {
    case placeNotFound(String)
    case offline(String)
    case badAnswer(String)

    var errorDescription: String? {
        switch self {
        case .placeNotFound(let query):
            return "No place found for “\(query)”."
        case .offline(let message):
            return "Network problem: \(message)"
        case .badAnswer(let message):
            return "Unexpected answer from Open-Meteo: \(message)"
        }
    }
}

/// Open-Meteo: free forecast and geocoding, no API key, no account.
/// Data by Open-Meteo.com (CC BY 4.0).
enum WeatherClient {
    static func geocode(_ query: String) async throws -> WeatherPlace {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw WeatherError.placeNotFound(text) }

        var collected: [GeocodeAnswer.Result] = []
        var failure: Error?
        for language in searchLanguages {
            do {
                collected.append(contentsOf: try await search(text, language: language))
            } catch {
                failure = error
            }
        }

        guard let best = bestMatch(in: collected) else {
            if let failure { throw failure }
            throw WeatherError.placeNotFound(text)
        }

        let name = [best.name, best.country].compactMap { $0 }.joined(separator: ", ")
        return WeatherPlace(name: name, latitude: best.latitude, longitude: best.longitude)
    }

    /// The geocoder matches the name *in the language it is asked for*: "Milano" is found with
    /// Italian but not with English (which answers "Milanówek, Poland"), while "New York" is the
    /// same everywhere. So the search is tried in the system language plus the two languages this
    /// app is used in, and the answers are merged.
    static var searchLanguages: [String] {
        var languages = [Locale.current.language.languageCode?.identifier ?? "en"]
        for candidate in ["it", "en"] where !languages.contains(candidate) {
            languages.append(candidate)
        }
        return languages
    }

    /// Candidates are ranked by population, but only among *populated places*: the country Romania
    /// also matches "Roma" and has nineteen million people.
    private static func bestMatch(in results: [GeocodeAnswer.Result]) -> GeocodeAnswer.Result? {
        let places = results.filter { ($0.feature_code ?? "").hasPrefix("PPL") }
        let pool = places.isEmpty ? results : places
        return pool.max { ($0.population ?? 0) < ($1.population ?? 0) }
    }

    private static func search(_ text: String, language: String) async throws -> [GeocodeAnswer.Result] {
        guard let escaped = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(escaped)&count=100&language=\(language)&format=json") else {
            throw WeatherError.placeNotFound(text)
        }

        let data = try await fetch(url)
        do {
            return try JSONDecoder().decode(GeocodeAnswer.self, from: data).results ?? []
        } catch {
            throw WeatherError.badAnswer(error.localizedDescription)
        }
    }

    /// Diagnostic helper: every place the geocoder returns for a name, to tune the ranking.
    static func candidates(for query: String) async throws -> [String] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var collected: [GeocodeAnswer.Result] = []
        for language in searchLanguages {
            collected.append(contentsOf: (try? await search(text, language: language)) ?? [])
        }

        let region = Locale.current.region?.identifier ?? "-"
        let top = collected
            .sorted { ($0.population ?? 0) > ($1.population ?? 0) }
            .prefix(8)
        return ["languages tried: \(searchLanguages.joined(separator: ", "))",
                "region of this Mac: \(region), locale: \(Locale.current.identifier)",
                "candidates: \(collected.count), most populated first:"] + top.map {
            "\($0.name) | \($0.country ?? "-") (\($0.country_code ?? "-")) [\($0.feature_code ?? "-")] pop=\($0.population.map(String.init) ?? "nil")  \($0.latitude),\($0.longitude)"
        }
    }

    static func forecast(latitude: Double, longitude: Double) async throws -> [DailyForecast] {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(latitude)&longitude=\(longitude)"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&forecast_days=7&timezone=auto"
        guard let url = URL(string: urlString) else {
            throw WeatherError.badAnswer("bad coordinates")
        }

        let data = try await fetch(url)
        let answer: ForecastAnswer
        do {
            answer = try JSONDecoder().decode(ForecastAnswer.self, from: data)
        } catch {
            throw WeatherError.badAnswer(error.localizedDescription)
        }

        guard let daily = answer.daily else { throw WeatherError.badAnswer("no daily block") }

        var result: [DailyForecast] = []
        for index in daily.time.indices {
            guard let day = WeatherClient.dayFormatter.date(from: daily.time[index]),
                  index < daily.weather_code.count,
                  index < daily.temperature_2m_max.count,
                  index < daily.temperature_2m_min.count else { continue }
            result.append(DailyForecast(day: day,
                                        code: daily.weather_code[index],
                                        maximum: daily.temperature_2m_max[index],
                                        minimum: daily.temperature_2m_min[index]))
        }
        return result
    }

    // MARK: - Plumbing

    /// The daily dates come as "2026-10-02" in the timezone asked for with `timezone=auto`.
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Kalendario", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WeatherError.offline(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WeatherError.badAnswer("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        return data
    }
}

private struct GeocodeAnswer: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let country_code: String?
        let feature_code: String?
        let population: Int?
    }

    let results: [Result]?
}

private struct ForecastAnswer: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }

    let daily: Daily?
}