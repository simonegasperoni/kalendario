import AppKit
import SwiftUI

/// Deals only with the main window: a plain, resizable macOS window with a title bar
/// and traffic lights. Nothing is forced about its level or appearance.
final class WindowManager {
    static let shared = WindowManager()

    private weak var window: NSWindow?

    private init() {}

    func attach(window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        window.title = "Kalendario"
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 1020, height: 640)
        window.collectionBehavior = [.fullScreenPrimary]
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