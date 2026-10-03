import Foundation
import Observation

/// The metadata of the GitHub repositories the calendar imported issues from: for now, how many
/// commits each one has on each day of the week on screen. Nothing is written to the data file; the
/// last numbers are kept in the preferences so the row can show them at launch without touching the
/// keychain.
@Observable
final class RepoMetaModel {
    struct Repository: Identifiable, Equatable {
        let name: String
        /// One entry per day of the week on screen, Monday first.
        var days: [Int?] = Array(repeating: nil, count: 7)
        var failure: String?

        var id: String { name }

        var total: Int { days.compactMap { $0 }.reduce(0, +) }

        /// The name without the owner, for the small line inside a day cell.
        var shortName: String {
            name.split(separator: "/").last.map(String.init) ?? name
        }
    }

    var repositories: [Repository] = []
    var isLoading = false
    var hasLoaded = false
    /// Whether a token is in the keychain, asked by attributes only so no password is prompted.
    var tokenStored = false
    /// Whether the last read already used the token: when it did and still failed, pointing at the
    /// button again would be a lie.
    var usedToken = false

    /// The repositories written by hand in the settings. They are configuration, like the weather
    /// place, so they live in the preferences and not in the calendar file.
    private(set) var configured: [String] = []
    /// What is being typed in the settings field.
    var newRepository = ""

    private static let listKey = "kalendario.github.repositories"

    init() {
        configured = UserDefaults.standard.stringArray(forKey: Self.listKey) ?? []
    }

    /// What the row reads: the repositories written by hand **plus** the ones the imported issues
    /// come from. The two are independent — the commits show even with no issue at all — and writing
    /// one here means not having to import anything from it.
    func names(imported: [String]) -> [String] {
        var seen = Set<String>()
        return (configured + imported.map { GitHubClient.normalize($0) })
            .filter { GitHubClient.isValid($0) && seen.insert($0).inserted }
    }

    /// Adds a repository written in the settings. Returns false when the name is not `owner/name`
    /// or is already there.
    @discardableResult
    func addRepository(_ raw: String) -> Bool {
        let name = GitHubClient.normalize(raw)
        guard GitHubClient.isValid(name), !configured.contains(name) else { return false }
        configured.append(name)
        UserDefaults.standard.set(configured, forKey: Self.listKey)
        return true
    }

    func removeRepository(_ name: String) {
        configured.removeAll { $0 == name }
        UserDefaults.standard.set(configured, forKey: Self.listKey)
    }

    /// True when what is being typed can be added.
    var canAddRepository: Bool {
        let name = GitHubClient.normalize(newRepository)
        return GitHubClient.isValid(name) && !configured.contains(name)
    }

    private static let weekKey = "kalendario.repoMeta.week"
    private static func cacheKey(_ name: String) -> String { "kalendario.repoMeta." + name }

    /// The numbers kept from the last read of the same week. Shown straight away, so the row is
    /// never blank and the keychain is not read just to fill it.
    func loadCache(for week: Date, names: [String]) {
        let defaults = UserDefaults.standard
        guard let stored = defaults.object(forKey: Self.weekKey) as? Date,
              WeekMath.isSameDay(stored, week) else { return }

        let cached = names.map { name -> Repository in
            var entry = Repository(name: name)
            if let days = defaults.array(forKey: Self.cacheKey(name)) as? [Int], days.count == 7 {
                entry.days = days.map { Optional($0) }
            }
            return entry
        }
        guard cached.contains(where: { $0.days.contains { $0 != nil } }) else { return }
        repositories = cached
        hasLoaded = true
    }

    private func saveCache(for week: Date) {
        let defaults = UserDefaults.standard
        defaults.set(week, forKey: Self.weekKey)
        for repository in repositories where repository.days.contains(where: { $0 != nil }) {
            defaults.set(repository.days.map { $0 ?? 0 }, forKey: Self.cacheKey(repository.name))
        }
    }

    /// Reads the commits of every day of the week, for every repository.
    ///
    /// Without `useToken` the token is left alone, so launching the app never reads the keychain and
    /// never asks for the password: public repositories answer anyway. `useToken` is what the button
    /// in the row does, for the private ones — that is when macOS may ask for the keychain password.
    /// At the first refusal the remaining days are skipped, so a private repository does not cost
    /// seven failed requests.
    func refresh(_ names: [String], week: Date, useToken: Bool) async {
        guard !names.isEmpty else {
            repositories = []
            hasLoaded = true
            return
        }

        isLoading = true
        tokenStored = TokenStore.hasStoredToken
        usedToken = useToken
        let client = GitHubClient(token: useToken ? TokenStore.token() : nil)
        let days = WeekMath.daysInWeek(from: week)

        var results: [Repository] = []
        for name in names {
            var entry = Repository(name: name)
            for (index, day) in days.enumerated() {
                let from = WeekMath.makeDate(day: day, hour: 0)
                let to = WeekMath.calendar.date(byAdding: .day, value: 1, to: from)
                do {
                    entry.days[index] = try await client.commitCount(repository: name,
                                                                     from: from,
                                                                     to: to)
                } catch {
                    entry.failure = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    break
                }
            }
            results.append(entry)
        }

        repositories = results
        isLoading = false
        hasLoaded = true
        saveCache(for: week)
    }

    /// Numbers for the static previews, so the row can be checked without the network.
    func setForPreview() {
        // One repository written by hand and one coming from an imported issue: the preview shows
        // the list in the settings and the union on the row.
        configured = ["apple/swift-nio"]
        repositories = [
            Repository(name: "apple/swift-nio", days: [2, 0, 1, 0, 3, 0, 1]),
            Repository(name: "swiftlang/swift", days: [12, 8, 4, 9, 7, 0, 3])
        ]
        hasLoaded = true
    }

    static func countText(_ commits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        let number = formatter.string(from: NSNumber(value: commits)) ?? "\(commits)"
        return "\(number) commit\(commits == 1 ? "" : "s")"
    }

    static func dayText(_ commits: Int?) -> String {
        guard let commits else { return "–" }
        return "\(commits)"
    }
}