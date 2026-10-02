import AppKit
import SwiftUI

/// Hides the window instead of closing it, so the app keeps it and can show it again when the
/// Dock icon is clicked. Every other delegate call is forwarded to SwiftUI's own window
/// controller (`forward`), which must keep receiving its notifications.
final class HidingWindowDelegate: NSObject, NSWindowDelegate {
    weak var forward: NSWindowDelegate?

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(NSWindowDelegate.windowShouldClose(_:)) { return true }
        return super.responds(to: aSelector) || (forward?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? { forward }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        WindowWatch.note("windowShouldClose -> hid the window instead of closing")
        return false
    }
}

/// Deals only with the main window: a plain, resizable macOS window with a title bar
/// and traffic lights. Nothing is forced about its level or appearance.
final class WindowManager {
    static let shared = WindowManager()

    private weak var window: NSWindow?
    private let proxy = HidingWindowDelegate()

    private init() {}

    func attach(window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        window.title = "Kalendario"
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 900, height: 560)
        window.collectionBehavior = [.fullScreenPrimary]

        proxy.forward = window.delegate
        window.delegate = proxy
    }

    /// Shows the main window again after it was hidden. Called when the app is reopened.
    @discardableResult
    func showMainWindow() -> Bool {
        guard let window else {
            WindowWatch.note("showMainWindow: no window to show")
            return false
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        WindowWatch.note("showMainWindow: shown")
        return true
    }

    var isWindowLoaded: Bool { window != nil }
}

/// Counts the visible windows over time, closing them once, so the "close the window and click
/// the Dock icon" path can be checked from the shell. Usage: --window-watch <seconds> [file]
enum WindowWatch {
    private static var lines: [String] = []
    private static var logPath: String?

    /// Appends a line from anywhere in the app (views and delegates included).
    static func note(_ text: String) {
        guard logPath != nil else { return }
        lines.append("               note: \(text)")
        flush()
    }

    private static func flush() {
        guard let logPath else { return }
        let report = lines.joined(separator: "\n") + "\n"
        try? report.write(toFile: logPath, atomically: true, encoding: .utf8)
    }

    static func start(seconds: Int, path: String?) {
        let file = path ?? (NSTemporaryDirectory() + "kalendario-window-watch.txt")
        logPath = file
        lines = []
        let started = Date()
        var didClose = false

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(started)
            let all = NSApp.windows
            let visible = all.filter { $0.isVisible }
            lines.append(String(format: "t=%4.1fs  windows: %d (visible %d)  delegate=%@",
                                elapsed, all.count, visible.count,
                                all.first?.delegate.map { String(describing: type(of: $0)) } ?? "nil"))

            if !didClose, elapsed >= 2 {
                didClose = true
                // performClose is the path of ⌘W and of the red button; close() would skip
                // windowShouldClose and therefore would not test the app's own behaviour.
                visible.forEach { $0.performClose(nil) }
                lines.append("          -> performClose on the window (as ⌘W does)")
            }

            flush()

            if elapsed >= Double(seconds) {
                timer.invalidate()
                NSApp.terminate(nil)
            }
        }
    }
}

struct WindowProbe: NSViewRepresentable {
    func makeNSView(context: NSViewRepresentableContext<WindowProbe>) -> NSView { ProbeView() }
    func updateNSView(_ nsView: NSView, context: NSViewRepresentableContext<WindowProbe>) {}

    private final class ProbeView: NSView {
        init() { super.init(frame: .zero) }
        required init?(coder: NSCoder) { super.init(coder: coder) }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            WindowManager.shared.attach(window: window)
        }
    }
}