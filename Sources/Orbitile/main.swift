import AppKit
import OrbitileCore
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let tap = MouseTap()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = MenuBarIcon.make()
        let menu = NSMenu()
        menu.delegate = self
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Only works from the bundled app (dist/Orbitile.app), not from `swift run`.
            fputs("Orbitile: launch at login failed: \(error.localizedDescription)\n", stderr)
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

    // Menu bar mark at 1x, 2x and 12x, on light and dark bars.
    let icon = MenuBarIcon.make()
    let big = MenuBarIcon.make(side: 18)
    func bar(_ name: String, dark: Bool) {
        let tint: NSColor = dark ? .white : .black
        let bg: Color = dark ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color(red: 0.93, green: 0.93, blue: 0.94)
        let view = HStack(spacing: 24) {
            Image(nsImage: icon).renderingMode(.template).resizable().frame(width: 18, height: 18)
            Image(nsImage: big).renderingMode(.template).resizable().frame(width: 216, height: 216)
        }
        .foregroundStyle(Color(nsColor: tint)).padding(24).background(bg)
        let r = ImageRenderer(content: view)
        r.scale = 2
        if let t = r.nsImage?.tiffRepresentation, let png = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
    }
    bar("menubar-light", dark: false)
    bar("menubar-dark", dark: true)
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
