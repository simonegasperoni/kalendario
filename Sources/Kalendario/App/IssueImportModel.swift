import Foundation
import Observation

/// State of the "Import GitHub issues" sheet.
@Observable
final class IssueImportModel {
    private enum Key {
        static let repository = "kalendario.githubRepository"
        static let includeClosed = "kalendario.githubIncludeClosed"
        static let labels = "kalendario.githubLabels"
        static let limit = "kalendario.githubLimit"
        static let stepMinutes = "kalendario.issueStepMinutes"
        static let durationMinutes = "kalendario.issueDurationMinutes"
    }

    var repository: String = UserDefaults.standard.string(forKey: Key.repository) ?? ""
    var labelsFilter: String = UserDefaults.standard.string(forKey: Key.labels) ?? ""
    var includeClosed: Bool = UserDefaults.standard.bool(forKey: Key.includeClosed)
    var limit: Int = UserDefaults.standard.object(forKey: Key.limit) as? Int ?? 30
    var stepMinutes: Int = UserDefaults.standard.object(forKey: Key.stepMinutes) as? Int ?? 30
    var durationMinutes: Int = UserDefaults.standard.object(forKey: Key.durationMinutes) as? Int ?? 30

    var status: String = ""
    var issues: [GitHubIssue] = []
    var selected: Set<Int> = []
    var loadedRepository: String?
    var isLoading = false
    var isRefreshing = false

    var day: Date = Date()
    var hour: Int = 9
    var category: EventCategory = .work

    var tokenInput: String = ""
    var hasStoredToken: Bool = TokenStore.hasStoredToken

    var labelList: [String] {
        labelsFilter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var selectedIssues: [GitHubIssue] { issues.filter { selected.contains($0.number) } }
    var allSelected: Bool { !issues.isEmpty && selected.count == issues.count }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(repository, forKey: Key.repository)
        defaults.set(labelsFilter, forKey: Key.labels)
        defaults.set(includeClosed, forKey: Key.includeClosed)
        defaults.set(limit, forKey: Key.limit)
        defaults.set(stepMinutes, forKey: Key.stepMinutes)
        defaults.set(durationMinutes, forKey: Key.durationMinutes)
    }

    func saveToken() {
        let value = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let stored = TokenStore.save(value)
        tokenInput = ""
        hasStoredToken = TokenStore.hasStoredToken
        status = stored
            ? "Token stored in the Keychain."
            : "The Keychain refused to store the token."
    }

    func clearToken() {
        TokenStore.delete()
        tokenInput = ""
        hasStoredToken = TokenStore.hasStoredToken
        status = "Token removed from the Keychain."
    }

    func toggle(_ number: Int) {
        if selected.contains(number) {
            selected.remove(number)
        } else {
            selected.insert(number)
        }
    }

    func selectAll() { selected = Set(issues.map(\.number)) }
    func selectNone() { selected = [] }
}