import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = MenuBarAppDelegate()
    app.delegate = delegate
    app.run()
}
