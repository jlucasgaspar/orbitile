import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let tap = MouseTap()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Orbitile")
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Orbitile", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        statusItem = status

        // Accessibility is required both for the window under the cursor and for moving it.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            fputs("Orbitile: grant Accessibility access, then relaunch.\n", stderr)
            return
        }
        if !tap.start() {
            fputs("Orbitile: could not create the event tap (check Input Monitoring).\n", stderr)
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
