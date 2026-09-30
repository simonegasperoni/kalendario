import SwiftUI
import AppKit

enum PreviewRenderer {
    static func write(to url: URL, dark: Bool, size: CGSize) {
        MainActor.assumeIsolated {
            let store = DataStore(inMemory: true)
            AppState.shared.store = store
            AppState.shared.weekStart = WeekMath.startOfWeek(Date())

            let view = RootView()
                .environment(store)
                .environment(\.kalendarioPreview, true)
                .environment(\.colorScheme, dark ? .dark : .light)
                .frame(width: size.width, height: size.height)

            render(view, to: url, dark: dark)
        }
    }

    /// Renders the top bar alone: useful to check the logo mark, the counters and the buttons.
    static func writeHeader(to url: URL, dark: Bool, size: CGSize) {
        MainActor.assumeIsolated {
            let store = DataStore(inMemory: true)
            AppState.shared.store = store
            AppState.shared.weekStart = WeekMath.startOfWeek(Date())

            let view = VStack(spacing: 0) {
                HeaderBar()
                Spacer(minLength: 0)
            }
            .environment(store)
            .environment(\.kalendarioPreview, true)
            .environment(\.colorScheme, dark ? .dark : .light)
            .background(Theme.paper)
            .frame(width: size.width, height: size.height)

            render(view, to: url, dark: dark)
        }
    }

    /// Renders the "Work places" sheet with the sample places, to check its layout.
    static func writePlaces(to url: URL, dark: Bool, size: CGSize) {
        MainActor.assumeIsolated {
            let store = DataStore(inMemory: true)
            AppState.shared.store = store

            let view = WorkLocationsView()
                .environment(store)
                .environment(\.kalendarioPreview, true)
                .environment(\.colorScheme, dark ? .dark : .light)
                .frame(width: size.width, height: size.height)

            render(view, to: url, dark: dark)
        }
    }

    /// Renders the "Import GitHub issues" sheet with sample data, to check its layout.
    static func writeImport(to url: URL, dark: Bool, size: CGSize) {
        MainActor.assumeIsolated {
            let model = IssueImportModel()
            model.repository = "example/planner"
            model.loadedRepository = "example/planner"
            model.issues = sampleIssues
            model.selected = Set(sampleIssues.map(\.number))
            model.status = "\(sampleIssues.count) issues from example/planner."
            model.day = WeekMath.startOfWeek(Date())

            // One event already imported, so the "Update imported" footer button shows up.
            let store = DataStore(inMemory: true)
            var imported = CalendarEvent()
            imported.title = "#405 Import issues from GitHub"
            imported.start = WeekMath.makeDate(day: WeekMath.startOfWeek(Date()), hour: 9)
            imported.durationMinutes = 30
            imported.notes = "feature, github\nhttps://github.com/example/planner/issues/405"
            imported.issue = IssueRef(repo: "example/planner", number: 405,
                                      url: "https://github.com/example/planner/issues/405",
                                      labels: ["feature", "github"], state: "open", updatedAt: Date())
            store.events.append(imported)
            AppState.shared.store = store

            let view = IssueImportView(model: model)
                .environment(\.kalendarioPreview, true)
                .environment(\.colorScheme, dark ? .dark : .light)
                .frame(width: size.width, height: size.height)

            render(view, to: url, dark: dark)
        }
    }

    private static var sampleIssues: [GitHubIssue] {
        let monday = WeekMath.startOfWeek(Date())
        func day(_ offset: Int) -> Date { WeekMath.date(dayOfWeek: offset, inWeekFrom: monday) }
        func issue(_ number: Int, _ title: String, _ labels: [String],
                   state: String = "open", due: Date? = nil, assignees: [String] = []) -> GitHubIssue {
            GitHubIssue(number: number, title: title, state: state,
                        url: "https://github.com/example/planner/issues/\(number)",
                        labels: labels, assignees: assignees, body: nil,
                        milestoneDue: due, updatedAt: Date())
        }

        return [
            issue(412, "Week view: drag an event to another day", ["enhancement", "ui"], due: day(2), assignees: ["simo"]),
            issue(409, "Sticky notes: shortcut to add a task", ["enhancement"]),
            issue(405, "Import issues from GitHub", ["feature", "github"], due: day(4), assignees: ["simo"]),
            issue(398, "Dark mode: hour labels too faint", ["bug"], state: "closed"),
            issue(391, "Export the week as PDF", ["idea"]),
            issue(388, "Support several windows", ["discussion"])
        ]
    }

    private static func render<V: View>(_ view: V, to url: URL, dark: Bool) {
        MainActor.assumeIsolated {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            renderer.isOpaque = true

            guard let cgImage = renderer.cgImage else {
                FileHandle.standardError.write(Data("render failed\n".utf8))
                exit(1)
            }

            let rep = NSBitmapImageRep(cgImage: cgImage)
            guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }

            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try data.write(to: url)
                print("preview: \(url.path) (\(Int(cgImage.width))x\(Int(cgImage.height)))")
            } catch {
                FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
                exit(1)
            }
        }
    }
}

enum AppIconRenderer {
    static func writeIconset(to directory: URL) {
        MainActor.assumeIsolated {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let variants: [(String, Int)] = [
                ("icon_16x16.png", 16),
                ("icon_16x16@2x.png", 32),
                ("icon_32x32.png", 32),
                ("icon_32x32@2x.png", 64),
                ("icon_128x128.png", 128),
                ("icon_128x128@2x.png", 256),
                ("icon_256x256.png", 256),
                ("icon_256x256@2x.png", 512),
                ("icon_512x512.png", 512),
                ("icon_512x512@2x.png", 1024)
            ]

            for (name, size) in variants {
                guard let data = png(size: size) else { continue }
                try? data.write(to: directory.appendingPathComponent(name))
            }
            print("iconset: \(directory.path)")
        }
    }

    private static func png(size: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(size: CGFloat(size))
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    private static func draw(size: CGFloat) {
        let bounds = NSRect(x: 0, y: 0, width: size, height: size)
        let radius = size * 0.225

        // Black background, in the rounded-square shape of macOS app icons.
        NSColor.hex("#0A0A0A").setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        // Hairline inside the edge: keeps the icon silhouette readable on dark backgrounds.
        NSColor.white.withAlphaComponent(0.09).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.006, dy: size * 0.006),
                                  xRadius: radius * 0.97, yRadius: radius * 0.97)
        border.lineWidth = max(1, size * 0.007)
        border.stroke()

        // White Times "K", centred on the cap height of the glyph.
        let fontSize = size * 0.78
        let font = NSFont(name: "TimesNewRomanPS-BoldMT", size: fontSize)
            ?? NSFont(name: "Times New Roman Bold", size: fontSize)
            ?? NSFont(name: "Times New Roman", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)

        let letter = NSAttributedString(string: "K", attributes: [
            .font: font,
            .foregroundColor: NSColor.white
        ])
        let letterSize = letter.size()
        let origin = NSPoint(
            x: (size - letterSize.width) / 2,
            y: size / 2 - font.capHeight / 2 + font.descender
        )
        letter.draw(at: origin)
    }
}