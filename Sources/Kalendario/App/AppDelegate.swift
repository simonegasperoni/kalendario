import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let seconds = LaunchOptions.windowWatchSeconds {
            WindowWatch.start(seconds: seconds, path: LaunchOptions.windowWatchPath)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Closing the window keeps the app alive; the Dock click has to bring the window back.
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowWatch.note("reopen event, hasVisibleWindows=\(flag)")
        WindowManager.shared.showMainWindow()
        return true
    }
}

