import Foundation

enum GitHubError: LocalizedError {
    case invalidRepository
    case unauthorized
    case refused(String?)
    case notFound(repository: String, hasToken: Bool)
    case rateLimited(reset: Date?)
    case server(Int)
    case offline(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return "Use the owner/name form, for example swiftlang/swift."
        case .unauthorized:
            return "GitHub rejected the token: check it, or clear it to browse public repositories."
        case .refused(let message):
            var text = "GitHub refused this request"
            if let message, !message.isEmpty { text += ": \(message)" }
            return text + ". A fine-grained token needs the **Contents: read** permission for the commit count, and **Issues: read** for the import; a classic token needs the repo scope."
        case .notFound(let repository, let hasToken):
            if hasToken {
                return "Repository \(repository) not found, or the token cannot see it."
            }
            return "Repository \(repository) not found. If it is private, add a token that can read it."
        case .rateLimited(let reset):
            if let reset {
                return "GitHub rate limit reached. It resets around \(DateText.hourMinute.string(from: reset)). Add a token for a much higher limit."
            }
            return "GitHub rate limit reached. Add a token for a much higher limit."
        case .server(let code):
            return "GitHub answered with status \(code). Try again in a moment."
        case .offline(let message):
            return "Network problem: \(message)"
        case .decoding(let message):
            return "Unexpected answer from GitHub: \(message)"
        }
    }
}

struct GitHubIssue: Identifiable, Hashable {
    let number: Int
    let title: String
    let state: String
    let url: String
    let labels: [String]
    let assignees: [String]
    let body: String?
    let milestoneDue: Date?
    let updatedAt: Date?

    var id: Int { number }
    var isClosed: Bool { state.caseInsensitiveCompare("closed") == .orderedSame }

    var reference: String { "#\(number)" }

    var notesPreview: String {
        var parts: [String] = []
        if !labels.isEmpty { parts.append(labels.joined(separator: ", ")) }
        if !assignees.isEmpty { parts.append("@" + assignees.joined(separator: ", @")) }
        if !url.isEmpty { parts.append(url) }
        return parts.joined(separator: "\n")
    }

    /// The issue body, line by line, cleaned up so it can become the to-do list of a sticky note:
    /// markdown bullets, checkboxes, numbered lists and heading marks are removed, empty lines
    /// dropped, and each line is capped so a paragraph does not turn into an endless task.
    var todoLines: [String] {
        guard let body, !body.isEmpty else { return [] }

        var lines: [String] = []
        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: true) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)

            for marker in ["- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "+ "]
            where line.hasPrefix(marker) {
                line.removeFirst(marker.count)
                break
            }

            if let dot = line.firstIndex(of: "."), line.distance(from: line.startIndex, to: dot) <= 2,
               line[line.startIndex..<dot].allSatisfy(\.isNumber) {
                line = line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces)
            }

            line = line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            guard !line.isEmpty else { continue }

            if line.count > 120 { line = String(line.prefix(117)) + "…" }
            lines.append(line)
            if lines.count >= 20 { break }
        }
        return lines
    }
}

/// Minimal read-only GitHub client: lists issues of one repository.
/// Uses the REST API v3 without ever logging the token.
struct GitHubClient {
    var token: String?

    private static let baseURL = URL(string: "https://api.github.com")!
    private static let pageCap = 5

    func issues(repository rawRepository: String,
                state: String = "open",
                labels: [String] = [],
                limit: Int = 30) async throws -> [GitHubIssue] {
        let repository = Self.normalize(rawRepository)
        guard Self.isValid(repository) else { throw GitHubError.invalidRepository }

        var collected: [GitHubIssue] = []
        var page = 1
        let pageSize = min(100, max(10, limit))

        while collected.count < limit && page <= Self.pageCap {
            let url = try Self.makeURL(repository: repository, state: state,
                                       labels: labels, page: page, pageSize: pageSize)
            let (data, _) = try await send(url, repository: repository)

            let payload: [IssueDTO]
            do {
                payload = try JSONDecoder.github.decode([IssueDTO].self, from: data)
            } catch {
                throw GitHubError.decoding(error.localizedDescription)
            }

            // The issues endpoint also returns pull requests: they are filtered out here.
            collected.append(contentsOf: payload.filter { !$0.isPullRequest }.map(\.issue))

            if payload.count < pageSize { break }
            page += 1
        }

        return Array(collected.prefix(limit))
    }

    // MARK: - Request

    /// How many commits the repository has on its default branch, as GitHub counts them: one
    /// request, asking for a single commit per page, and reading the number of the "last" page out
    /// of the Link header. No Link header means one page, so the commits in it are all there are.
    /// With `from`/`to` it counts only the commits of that window (a day of the week, usually).
    func commitCount(repository rawRepository: String,
                     from: Date? = nil,
                     to: Date? = nil) async throws -> Int {
        let repository = Self.normalize(rawRepository)
        guard Self.isValid(repository) else { throw GitHubError.invalidRepository }

        let url = try Self.makeCommitCountURL(repository: repository, from: from, to: to)
        let (data, response) = try await send(url, repository: repository)
        if let link = response.value(forHTTPHeaderField: "Link"),
           let count = Self.lastPage(in: link) {
            return count
        }
        return ((try? JSONDecoder.github.decode([CommitDTO].self, from: data)) ?? []).count
    }

    /// The "message" field of a GitHub error body, if there is one.
    private static func serverMessage(in data: Data) -> String? {
        struct Payload: Decodable { let message: String? }
        return (try? JSONDecoder().decode(Payload.self, from: data))?.message
    }

    private static func lastPage(in link: String) -> Int? {
        for part in link.split(separator: ",") where part.contains("rel=\"last\"") {
            // The part looks like "<…?per_page=1&page=211547>; rel=\"last\"": the number wanted is
            // the one after the *last* "page=", because "per_page=1" contains "page=" too.
            guard let marker = part.range(of: "page=", options: .backwards) else { continue }
            return Int(part[marker.upperBound...].prefix { $0.isNumber })
        }
        return nil
    }

    private static func makeCommitCountURL(repository: String, from: Date?, to: Date?) throws -> URL {
        let components = repository.split(separator: "/", maxSplits: 1)
        guard components.count == 2 else { throw GitHubError.invalidRepository }

        var url = baseURL
        url.appendPathComponent("repos")
        url.appendPathComponent(String(components[0]))
        url.appendPathComponent(String(components[1]))
        url.appendPathComponent("commits")

        guard var builder = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GitHubError.invalidRepository
        }
        var items = [URLQueryItem(name: "per_page", value: "1")]
        if let from {
            items.append(URLQueryItem(name: "since", value: ISO8601DateFormatter.plain.string(from: from)))
        }
        if let to {
            items.append(URLQueryItem(name: "until", value: ISO8601DateFormatter.plain.string(from: to)))
        }
        builder.queryItems = items
        guard let finalURL = builder.url else { throw GitHubError.invalidRepository }
        return finalURL
    }

    private func send(_ url: URL, repository: String) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Kalendario", forHTTPHeaderField: "User-Agent")

        let hasToken = !(token ?? "").isEmpty
        if hasToken, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GitHubError.offline(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.offline("unexpected response")
        }

        switch http.statusCode {
        case 200...299:
            return (data, http)

        case 401:
            throw GitHubError.unauthorized

        case 403, 429:
            let remaining = http.value(forHTTPHeaderField: "X-RateLimit-Remaining")
            if remaining == "0" {
                let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
                    .flatMap { Double($0) }
                    .map { Date(timeIntervalSince1970: $0) }
                throw GitHubError.rateLimited(reset: reset)
            }
            // Not a rate limit: GitHub refused the request itself, and says why in the body ("Resource not
            // accessible by personal access token" is the usual answer when a permission is missing).
            throw GitHubError.refused(Self.serverMessage(in: data))

        case 404:
            throw GitHubError.notFound(repository: repository, hasToken: hasToken)

        default:
            throw GitHubError.server(http.statusCode)
        }
    }

    // MARK: - URL building

    private static func makeURL(repository: String, state: String, labels: [String],
                                page: Int, pageSize: Int) throws -> URL {
        let components = repository.split(separator: "/", maxSplits: 1)
        guard components.count == 2 else { throw GitHubError.invalidRepository }

        var url = baseURL
        url.appendPathComponent("repos")
        url.appendPathComponent(String(components[0]))
        url.appendPathComponent(String(components[1]))
        url.appendPathComponent("issues")

        guard var builder = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GitHubError.invalidRepository
        }
        var items = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "direction", value: "desc"),
            URLQueryItem(name: "per_page", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page))
        ]
        let labelList = labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !labelList.isEmpty {
            items.append(URLQueryItem(name: "labels", value: labelList.joined(separator: ",")))
        }
        builder.queryItems = items

        guard let finalURL = builder.url else { throw GitHubError.invalidRepository }
        return finalURL
    }

    /// Accepts "owner/name" and also a pasted "https://github.com/owner/name" URL.
    static func normalize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "github.com/") {
            text = String(text[range.upperBound...])
        }
        while text.hasSuffix("/") { text.removeLast() }
        let parts = text.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return text }
        return "\(parts[0])/\(parts[1])"
    }

    static func isValid(_ repository: String) -> Bool {
        let parts = repository.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { character in
                character.isLetter || character.isNumber || character == "-" || character == "_" || character == "."
            }
        }
    }
}

// MARK: - Decoding

/// Only the field the commit count needs, when there is no Link header to read the total from.
private struct CommitDTO: Decodable {
    let sha: String
}

private struct IssueDTO: Decodable {
    let number: Int
    let title: String
    let state: String
    let htmlURL: String?
    let body: String?
    let labels: [LabelDTO]?
    let assignees: [UserDTO]?
    let pullRequest: PullRequestRef?
    let milestone: MilestoneDTO?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case number, title, state, body, labels, assignees, milestone
        case htmlURL = "html_url"
        case pullRequest = "pull_request"
        case updatedAt = "updated_at"
    }

    var isPullRequest: Bool { pullRequest != nil }

    var issue: GitHubIssue {
        GitHubIssue(
            number: number,
            title: title,
            state: state,
            url: htmlURL ?? "",
            labels: (labels ?? []).map(\.name),
            assignees: (assignees ?? []).map(\.login),
            body: body,
            milestoneDue: milestone?.dueOn,
            updatedAt: updatedAt
        )
    }
}

private struct LabelDTO: Decodable {
    let name: String
}

private struct UserDTO: Decodable {
    let login: String
}

private struct PullRequestRef: Decodable {
    let url: String?
}

private struct MilestoneDTO: Decodable {
    let dueOn: Date?

    enum CodingKeys: String, CodingKey {
        case dueOn = "due_on"
    }
}

extension JSONDecoder {
    /// GitHub dates are ISO 8601, with or without fractional seconds depending on the field.
    static let github: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: text) { return date }
            if let date = ISO8601DateFormatter.plain.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unrecognised date: \(text)")
        }
        return decoder
    }()
}

extension ISO8601DateFormatter {
    static let plain = ISO8601DateFormatter()

    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}