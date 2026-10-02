import SwiftUI
import AppKit

@main
enum EntryPoint {
    static func main() {
        let options = LaunchOptions(arguments: CommandLine.arguments)

        switch options.task {
        case .preview(let url, let dark, let size):
            _ = NSApplication.shared
            PreviewRenderer.write(to: url, dark: dark, size: size)
            exit(0)

        case .header(let url, let dark, let size):
            _ = NSApplication.shared
            PreviewRenderer.writeHeader(to: url, dark: dark, size: size)
            exit(0)

        case .importPreview(let url, let dark, let size):
            _ = NSApplication.shared
            PreviewRenderer.writeImport(to: url, dark: dark, size: size)
            exit(0)

        case .places(let url, let dark, let size):
            _ = NSApplication.shared
            PreviewRenderer.writePlaces(to: url, dark: dark, size: size)
            exit(0)

        case .githubCheck(let repository):
            runGitHubCheck(repository)
            exit(0)

        case .jsonCheck(let path):
            runJSONCheck(path)

        case .icon(let directory):
            _ = NSApplication.shared
            AppIconRenderer.writeIconset(to: directory)
            exit(0)

        case .none:
            KalendarioApp.main()
        }
    }

    /// Diagnostic entry point: saves a snapshot that contains an imported issue and reads it back,
    /// then does the same on a copy with the "issue" key removed, as older files have.
    /// Usage: Kalendario --json-check [path.json]
    private static func runJSONCheck(_ path: URL?) {
        let url = path ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kalendario-json-check.json")

        var event = CalendarEvent()
        event.title = "#405 Import issues from GitHub"
        event.start = Date(timeIntervalSince1970: 1_790_000_000)
        event.durationMinutes = 45
        event.category = .work
        event.notes = "feature, github\nhttps://github.com/example/planner/issues/405"
        event.issue = IssueRef(repo: "example/planner",
                               number: 405,
                               url: "https://github.com/example/planner/issues/405",
                               labels: ["feature", "github"],
                               state: "closed",
                               updatedAt: Date(timeIntervalSince1970: 1_790_000_000))

        var note = StickyNote()
        note.title = "Weekly shopping"
        note.color = .yellow
        note.todos = [TodoItem(text: "Milk", isDone: true)]

        let office = WorkLocation(name: "Office", color: .green)

        var snapshot = KalendarioSnapshot()
        snapshot.events = [event]
        snapshot.notes = [note]
        snapshot.locations = [office]
        snapshot.assignments = [WeekMath.dayKey(event.start): office.id]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)

            let readBack = try decoder.decode(KalendarioSnapshot.self, from: data)
            guard let restored = readBack.events.first, let reference = restored.issue else {
                print("json-check: FAILED — the imported issue did not survive the round trip")
                exit(1)
            }

            print("json-check: ok")
            print("  file: \(url.path) (\(data.count) bytes)")
            print("  event: \(restored.title) [\(restored.category.rawValue)] \(restored.durationMinutes) min")
            print("  issue: \(reference.repo)#\(reference.number) state=\(reference.state) closed=\(reference.isClosed) labels=\(reference.labels.joined(separator: "|"))")
            print("  note: \(readBack.notes.first?.displayTitle ?? "-") color=\(readBack.notes.first?.color.rawValue ?? "-") todos=\(readBack.notes.first?.todos.count ?? 0)")
            print("  place: \(readBack.locations.first?.displayName ?? "-") color=\(readBack.locations.first?.color.rawValue ?? "-") days assigned=\(readBack.assignments.count)")

            // Fields added after the first release must not be required either.
            if var older = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                older.removeValue(forKey: "version")
                older.removeValue(forKey: "locations")
                older.removeValue(forKey: "assignments")
                let olderData = try JSONSerialization.data(withJSONObject: older)
                let olderSnapshot = try decoder.decode(KalendarioSnapshot.self, from: olderData)
                print("  file without \"version\"/\"locations\"/\"assignments\": version=\(olderSnapshot.version) places=\(olderSnapshot.locations.count) days=\(olderSnapshot.assignments.count) (defaults applied)")
            }

            // A file written before the import feature has no "issue" key: it must still decode.
            if var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let events = object["events"] as? [[String: Any]] {
                object["events"] = events.map { entry -> [String: Any] in
                    var copy = entry
                    copy.removeValue(forKey: "issue")
                    return copy
                }
                let legacyData = try JSONSerialization.data(withJSONObject: object)
                let legacy = try decoder.decode(KalendarioSnapshot.self, from: legacyData)
                let missing = legacy.events.first?.issue == nil
                print("  legacy file without \"issue\": decoded \(legacy.events.count) event, issue=\(missing ? "nil (correct)" : "present (wrong)")")
                if !missing {
                    print("json-check: FAILED — an old file was not decoded the way it should be")
                    exit(1)
                }
            }

            // An issue object with a missing field must not fail the whole file either.
            var tolerant = snapshot
            tolerant.events[0].issue = IssueRef(repo: "example/planner", number: 7, url: "")
            let tolerantData = try encoder.encode(tolerant)
            var object = try JSONSerialization.jsonObject(with: tolerantData) as? [String: Any]
            if var events = object?["events"] as? [[String: Any]], var first = events.first {
                first["issue"] = ["repo": "example/planner"]
                events[0] = first
                object?["events"] = events
                let partialData = try JSONSerialization.data(withJSONObject: object ?? [:])
                let partial = try decoder.decode(KalendarioSnapshot.self, from: partialData)
                print("  issue with only \"repo\": number=\(partial.events.first?.issue?.number ?? -1) state=\(partial.events.first?.issue?.state ?? "-") (defaults applied)")
            }
        } catch {
            print("json-check: FAILED — \(error)")
            exit(1)
        }
    }

    /// Diagnostic entry point: reads a repository through the real API and prints what was parsed.
    /// Usage: Kalendario --github-check owner/name
    private static func runGitHubCheck(_ repository: String) {
        let token = TokenStore.token()
        let client = GitHubClient(token: token)
        var report: [String] = []
        let finished = DispatchSemaphore(value: 0)

        Task {
            report.append("repository: \(GitHubClient.normalize(repository))")
            report.append("token: \(token == nil ? "none" : "present")")
            do {
                let issues = try await client.issues(repository: repository, state: "open", limit: 5)
                report.append("issues parsed: \(issues.count)")
                for issue in issues {
                    let labels = issue.labels.isEmpty ? "-" : issue.labels.joined(separator: "|")
                    let due = issue.milestoneDue.map { DateText.monthDayShort.string(from: $0) } ?? "-"
                    report.append("  \(issue.reference) [\(issue.state)] due=\(due) labels=\(labels)")
                    report.append("     \(issue.title)")
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                report.append("error: \(message)")
            }
            finished.signal()
        }

        if finished.wait(timeout: .now() + 40) == .timedOut {
            report.append("error: timed out waiting for GitHub")
        }
        report.forEach { print($0) }
    }
}

struct KalendarioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let app = AppState.shared

    var body: some Scene {
        WindowGroup("Kalendario", id: "main") {
            RootView()
                .environment(app.store)
                .background(WindowProbe())
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1380, height: 880)
        .commands {
            CommandMenu("Planner") {
                Button("New event") { AppState.shared.newEventInCurrentWeek() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("New sticky note") { AppState.shared.newNote() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button("Show window") { WindowManager.shared.showMainWindow() }
                    .keyboardShortcut("0", modifiers: .command)
            }
            CommandMenu("Week") {
                Button("Today") { AppState.shared.goToToday() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Previous week") { AppState.shared.previousWeek() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Next week") { AppState.shared.nextWeek() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
    }
}