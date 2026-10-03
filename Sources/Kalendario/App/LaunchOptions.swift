import Foundation

struct LaunchOptions {
    enum Task {
        case none
        case preview(url: URL, dark: Bool, size: CGSize)
        case header(url: URL, dark: Bool, size: CGSize)
        case importPreview(url: URL, dark: Bool, size: CGSize)
        case places(url: URL, dark: Bool, size: CGSize)
        case editor(url: URL, dark: Bool, size: CGSize)
        case settings(url: URL, dark: Bool, size: CGSize)
        case icon(directory: URL)
        case githubCheck(repository: String)
        case commitsCheck(repository: String)
        case weatherCheck(place: String)
        case weatherSearch(name: String)
        case notesCheck
        case statsCheck
        case jsonCheck(path: URL?)
    }

    /// Used by the app lifecycle to run the window watcher after launch.
    static var windowWatchSeconds: Int?
    static var windowWatchPath: String?

    var task: Task = .none

    init(arguments: [String]) {
        var dark = false
        var size = CGSize(width: 1440, height: 900)
        var previewURL: URL?
        var headerURL: URL?
        var importURL: URL?
        var placesURL: URL?
        var editorURL: URL?
        var settingsURL: URL?
        var iconURL: URL?
        var githubRepository: String?
        var commitsRepository: String?
        var weatherPlace: String?
        var weatherSearchName: String?
        var notesCheckRequested = false
        var statsCheckRequested = false
        var jsonCheckRequested = false
        var jsonCheckPath: URL?
        var watchSeconds: Int?
        var watchPath: String?

        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--render-preview":
                index += 1
                if index < arguments.count { previewURL = URL(fileURLWithPath: arguments[index]) }
            case "--render-header":
                index += 1
                if index < arguments.count { headerURL = URL(fileURLWithPath: arguments[index]) }
            case "--render-import":
                index += 1
                if index < arguments.count { importURL = URL(fileURLWithPath: arguments[index]) }
            case "--render-places":
                index += 1
                if index < arguments.count { placesURL = URL(fileURLWithPath: arguments[index]) }
            case "--render-editor":
                index += 1
                if index < arguments.count { editorURL = URL(fileURLWithPath: arguments[index]) }
            case "--render-settings":
                index += 1
                if index < arguments.count { settingsURL = URL(fileURLWithPath: arguments[index]) }
            case "--github-check":
                index += 1
                if index < arguments.count { githubRepository = arguments[index] }
            case "--commits-check":
                index += 1
                if index < arguments.count { commitsRepository = arguments[index] }
            case "--weather-check":
                index += 1
                if index < arguments.count { weatherPlace = arguments[index] }
            case "--weather-search":
                index += 1
                if index < arguments.count { weatherSearchName = arguments[index] }
            case "--notes-check":
                notesCheckRequested = true
            case "--stats-check":
                statsCheckRequested = true
            case "--json-check":
                jsonCheckRequested = true
                if index + 1 < arguments.count, arguments[index + 1].hasSuffix(".json") {
                    index += 1
                    jsonCheckPath = URL(fileURLWithPath: arguments[index])
                }
            case "--window-watch":
                if index + 1 < arguments.count, let seconds = Int(arguments[index + 1]) {
                    index += 1
                    watchSeconds = seconds
                }
                if index + 1 < arguments.count, arguments[index + 1].hasPrefix("/") {
                    index += 1
                    watchPath = arguments[index]
                }
            case "--render-icon":
                index += 1
                if index < arguments.count { iconURL = URL(fileURLWithPath: arguments[index]) }
            case "--dark":
                dark = true
            case "--size":
                index += 1
                if index < arguments.count, let parsed = LaunchOptions.parseSize(arguments[index]) { size = parsed }
            default:
                break
            }
            index += 1
        }

        if let iconURL {
            task = .icon(directory: iconURL)
        } else if let previewURL {
            task = .preview(url: previewURL, dark: dark, size: size)
        } else if let headerURL {
            task = .header(url: headerURL, dark: dark, size: size)
        } else if let importURL {
            task = .importPreview(url: importURL, dark: dark, size: size)
        } else if let placesURL {
            task = .places(url: placesURL, dark: dark, size: size)
        } else if let editorURL {
            task = .editor(url: editorURL, dark: dark, size: size)
        } else if let settingsURL {
            task = .settings(url: settingsURL, dark: dark, size: size)
        } else if let githubRepository {
            task = .githubCheck(repository: githubRepository)
        } else if let commitsRepository {
            task = .commitsCheck(repository: commitsRepository)
        } else if let weatherPlace {
            task = .weatherCheck(place: weatherPlace)
        } else if let weatherSearchName {
            task = .weatherSearch(name: weatherSearchName)
        } else if notesCheckRequested {
            task = .notesCheck
        } else if statsCheckRequested {
            task = .statsCheck
        } else if jsonCheckRequested {
            task = .jsonCheck(path: jsonCheckPath)
        }

        LaunchOptions.windowWatchSeconds = watchSeconds
        LaunchOptions.windowWatchPath = watchPath
    }

    private static func parseSize(_ raw: String) -> CGSize? {
        let parts = raw.lowercased().split(separator: "x")
        guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]) else { return nil }
        return CGSize(width: width, height: height)
    }
}