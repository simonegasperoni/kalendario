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

        case .editor(let url, let dark, let size):
            _ = NSApplication.shared
            PreviewRenderer.writeEditor(to: url, dark: dark, size: size)
            exit(0)

        case .settings(let url, let dark, let size):
            _ = NSApplication.shared
            PreviewRenderer.writeSettings(to: url, dark: dark, size: size)
            exit(0)

        case .weatherCheck(let place):
            runWeatherCheck(place)
            exit(0)

        case .weatherSearch(let name):
            runWeatherSearch(name)
            exit(0)

        case .githubCheck(let repository):
            runGitHubCheck(repository)
            exit(0)

        case .commitsCheck(let repository):
            runCommitsCheck(repository)
            exit(0)

        case .notesCheck:
            runNotesCheck()
            exit(0)

        case .statsCheck:
            runStatsCheck()
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

    /// Diagnostic entry point: reorders the sticky notes of a week the way the panel does with a
    /// drag, and reads the snapshot back, because a drag cannot be seen in a static render and the
    /// order has to survive the file.
    /// Usage: Kalendario --notes-check
    private static func runNotesCheck() {
        let store = DataStore(inMemory: true)
        let monday = WeekMath.startOfWeek(Date())

        func order() -> [String] { store.notes(inWeek: monday).map(\.displayTitle) }

        print("notes-check: \(order().count) notes this week")
        print("  start: \(order().joined(separator: " | "))")

        guard order().count >= 3 else {
            print("notes-check: FAILED — the seeded week needs at least 3 notes")
            exit(1)
        }

        let start = order()
        let notes = store.notes(inWeek: monday)

        // Drag the first note onto the last one: it lands before it.
        let movedBefore = store.moveNote(id: notes[0].id, before: notes[2].id, inWeek: monday)
        let afterBefore = order()
        print("  first onto third (\(movedBefore)): \(afterBefore.joined(separator: " | "))")
        let expectedBefore = [start[1], start[0], start[2]]
        guard movedBefore, afterBefore == expectedBefore else {
            print("notes-check: FAILED — expected \(expectedBefore.joined(separator: " | "))")
            exit(1)
        }

        // Drag the first note of the week into the free room at the end of the row: it goes last.
        let appended = store.moveNote(id: notes[0].id, before: nil, inWeek: monday)
        let afterAppend = order()
        print("  first to the end (\(appended)): \(afterAppend.joined(separator: " | "))")
        let expectedAppend = [start[1], start[2], start[0]]
        guard appended, afterAppend == expectedAppend else {
            print("notes-check: FAILED — expected \(expectedAppend.joined(separator: " | "))")
            exit(1)
        }

        // Drops that must not be accepted: the note on itself, an event, a note of another week.
        let otherWeek = WeekMath.addWeeks(1, to: monday)
        let otherNote = store.addNote(inWeek: otherWeek)
        let selfDrop = store.moveNote(id: notes[1].id, before: notes[1].id, inWeek: monday)
        let unknownDrop = store.moveNote(id: UUID(), before: notes[1].id, inWeek: monday)
        let crossWeek = store.moveNote(id: otherNote.id, before: notes[1].id, inWeek: monday)
        print("  rejected: on itself \(selfDrop), unknown id \(unknownDrop), other week \(crossWeek)")
        guard !selfDrop, !unknownDrop, !crossWeek, order() == expectedAppend else {
            print("notes-check: FAILED — a drop was accepted when it should not be, or the order moved")
            exit(1)
        }

        // The order is the array order in the file: it has to come back the same way.
        var snapshot = KalendarioSnapshot()
        snapshot.notes = store.notes
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try encoder.encode(snapshot)
            let restored = try decoder.decode(KalendarioSnapshot.self, from: data)
                .notes
                .filter { WeekMath.isSameDay($0.weekStart, monday) }
                .map(\.displayTitle)
            print("  after save/load: \(restored.joined(separator: " | "))")
            guard restored == expectedAppend else {
                print("notes-check: FAILED — the order did not survive the round trip")
                exit(1)
            }
        } catch {
            print("notes-check: FAILED — \(error)")
            exit(1)
        }

        print("notes-check: ok")
    }

    /// Diagnostic entry point: prints what the status row shows — CPU and GPU temperature, memory
    /// and disk use — because none of it can be read from a static render.
    /// Usage: Kalendario --stats-check
    private static func runStatsCheck() {
        let stats = SystemStats()
        stats.read()
        print("stats-check:")
        print("  CPU     \(SystemStats.temperature(stats.cpuTemperature))")
        print("  GPU     \(SystemStats.temperature(stats.gpuTemperature))")
        print("  memory  \(SystemStats.bytes(stats.memoryUsed, style: .memory)) of \(SystemStats.bytes(stats.memoryTotal, style: .memory)) (\(SystemStats.percent(stats.memoryFraction)))")
        print("  disk    \(SystemStats.bytes(stats.diskUsed, style: .file)) of \(SystemStats.bytes(stats.diskTotal, style: .file)) (\(SystemStats.percent(stats.diskFraction)))")
        let sensorsOK = stats.cpuTemperature != nil && stats.gpuTemperature != nil
        print(sensorsOK ? "stats-check: ok" : "stats-check: FAILED — the temperature sensors did not answer")
        if !sensorsOK { exit(1) }
    }

    /// Diagnostic entry point: lists every candidate the geocoder returns for a name.
    /// Usage: Kalendario --weather-search "Milano"
    private static func runWeatherSearch(_ name: String) {
        var report: [String] = []
        let finished = DispatchSemaphore(value: 0)

        Task {
            do {
                report = try await WeatherClient.candidates(for: name)
            } catch {
                report.append("error: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }
            finished.signal()
        }

        if finished.wait(timeout: .now() + 30) == .timedOut {
            report.append("error: timed out waiting for Open-Meteo")
        }
        report.forEach { print($0) }
    }

    /// Diagnostic entry point: geocodes a place and prints the forecast it gets back.
    /// Usage: Kalendario --weather-check "Milan"
    private static func runWeatherCheck(_ place: String) {
        var report: [String] = []
        let finished = DispatchSemaphore(value: 0)

        Task {
            do {
                let found = try await WeatherClient.geocode(place)
                report.append("place: \(found.name) (\(found.latitude), \(found.longitude))")
                let days = try await WeatherClient.forecast(latitude: found.latitude,
                                                           longitude: found.longitude)
                report.append("days: \(days.count)")
                for forecast in days {
                    let date = WeatherClient.dayFormatter.string(from: forecast.day)
                    report.append("  \(date)  \(forecast.symbol)  max \(forecast.maximumText)  min \(forecast.minimumText)  \(forecast.summary)")
                }
            } catch {
                report.append("error: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }
            finished.signal()
        }

        if finished.wait(timeout: .now() + 30) == .timedOut {
            report.append("error: timed out waiting for Open-Meteo")
        }
        report.forEach { print($0) }
    }

    /// Diagnostic entry point: the commits of every day of the current week — the numbers the row at
    /// the foot of the calendar shows — because a seven-request read is not visible in a render.
    /// Usage: Kalendario --commits-check owner/name
    private static func runCommitsCheck(_ repository: String) {
        let client = GitHubClient(token: TokenStore.token())
        let week = WeekMath.startOfWeek(Date())
        var report: [String] = []
        let finished = DispatchSemaphore(value: 0)

        Task {
            report.append("repository: \(GitHubClient.normalize(repository))")
            var total = 0
            for day in WeekMath.daysInWeek(from: week) {
                let from = WeekMath.makeDate(day: day, hour: 0)
                let to = WeekMath.calendar.date(byAdding: .day, value: 1, to: from)
                let label = "\(DateText.monthDayShort.string(from: day)) \(DateText.weekdayTitle(day))"
                do {
                    let count = try await client.commitCount(repository: repository,
                                                             from: from,
                                                             to: to)
                    total += count
                    report.append("  \(label): \(count)")
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    report.append("  \(label): \(message)")
                    report.append("  — the remaining days were not asked for")
                    break
                }
            }
            report.append("total for the week: \(total)")
            finished.signal()
        }

        if finished.wait(timeout: .now() + 60) == .timedOut {
            report.append("error: timed out waiting for GitHub")
        }
        report.forEach { print($0) }
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
                do {
                    let commits = try await client.commitCount(repository: repository)
                    report.append("commits on the default branch: \(RepoMetaModel.countText(commits))")
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    report.append("commits: \(message)")
                }
                for issue in issues {
                    let labels = issue.labels.isEmpty ? "-" : issue.labels.joined(separator: "|")
                    let due = issue.milestoneDue.map { DateText.monthDayShort.string(from: $0) } ?? "-"
                    report.append("  \(issue.reference) [\(issue.state)] due=\(due) labels=\(labels)")
                    report.append("     \(issue.title)")
                    let todos = issue.todoLines
                    report.append("     body → sticky note with \(todos.count) to-do lines:")
                    for line in todos.prefix(4) { report.append("       • \(line)") }
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
        .defaultSize(width: 1120, height: 900)
        .commands {
            CommandMenu("Planner") {
                Button("New event") { AppState.shared.newEventInCurrentWeek() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("New sticky note") { AppState.shared.newNote() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button("Show window") { WindowManager.shared.showMainWindow() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Settings…") { AppState.shared.showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
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