import AppKit
import OrbitileCore
import SwiftUI

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

/// `Orbitile --snapshot <dir>` renders the fan to PNGs without needing a screen or permissions.
@MainActor
func renderSnapshots(to dir: String) {
    func render(_ name: String, family: Int, cell: Int?, drag: Int?) {
        let model = FanModel()
        model.center = CGPoint(x: 170, y: 170)
        var state = FanState(family: family)
        if let cell { state.update(.cell(cell)) }
        if let drag { state.beginDrag(); state.update(.cell(drag)) }
        model.state = state
        let view = ZStack {
            Color(red: 0.12, green: 0.13, blue: 0.15)
            FanView(model: model, startOpened: true)
        }.frame(width: 340, height: 340)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
    render("open", family: 3, cell: nil, drag: nil)
    render("hover", family: 1, cell: 2, drag: nil)
    render("drag", family: 3, cell: 2, drag: 1)
}

if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { renderSnapshots(to: CommandLine.arguments[i + 1]) }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
