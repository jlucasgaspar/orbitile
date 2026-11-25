import AppKit
import OrbitileCore
import ServiceManagement
import SwiftUI

/// What the app can do right now. Anything but `.active` shows a hint in the menu.
enum Readiness {
    case active, needsAccessibility, needsInputMonitoring

    var message: String {
        switch self {
        case .active: "Orbitile is active"
        case .needsAccessibility: "Accessibility access needed"
        case .needsInputMonitoring: "Input Monitoring access needed"
        }
    }

    var settingsTitle: String? {
        switch self {
        case .active: nil
        case .needsAccessibility: "Open Accessibility Settings…"
        case .needsInputMonitoring: "Open Input Monitoring Settings…"
        }
    }

    var settingsURL: URL? {
        switch self {
        case .active: nil
        case .needsAccessibility: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .needsInputMonitoring: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "", action: #selector(openSettings), keyEquivalent: "")
    private static let enabledKey = "enabled"
    private let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private let aboutItem = NSMenuItem(title: "About Orbitile", action: #selector(showAbout), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let tap = MouseTap()
    private var statusItem: NSStatusItem?
    private var readiness = Readiness.needsAccessibility
    private var poll: Timer?
    private var lastLogged: Readiness?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = MenuBarIcon.make()
        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        settingsItem.target = self
        loginItem.target = self
        enabledItem.target = self
        aboutItem.target = self
        tap.isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        [statusLine, settingsItem, .separator(), enabledItem, loginItem, .separator(), aboutItem].forEach(menu.addItem)
        menu.addItem(withTitle: "Quit Orbitile", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        statusItem = status

        // Ask once at launch; after that the menu points to System Settings and we keep checking.
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        refreshReadiness()
    }

    /// Starts the event tap as soon as the permissions allow it, without a relaunch.
    private func refreshReadiness() {
        if !AXIsProcessTrusted() {
            // Also covers a grant revoked while running: drop the tap so nothing is swallowed.
            tap.stop()
            readiness = .needsAccessibility
        } else if tap.isRunning {
            readiness = .active
        } else {
            readiness = tap.start() ? .active : .needsInputMonitoring
        }
        if readiness != lastLogged {
            lastLogged = readiness
            Log.app.notice("readiness: \(String(describing: self.readiness), privacy: .public) (AX trusted: \(AXIsProcessTrusted()), listen access: \(CGPreflightListenEventAccess()), tap running: \(self.tap.isRunning))")
        }
        statusItem?.button?.appearsDisabled = readiness != .active || !tap.isEnabled
        statusItem?.button?.toolTip = statusText
        applyReadinessToMenu()

        // Always polling: it catches both a grant arriving and one being revoked.
        if poll == nil {
            poll = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshReadiness() }
            }
        }
    }

    private func applyReadinessToMenu() {
        statusLine.title = statusText
        enabledItem.state = tap.isEnabled ? .on : .off
        settingsItem.title = readiness.settingsTitle ?? ""
        settingsItem.isHidden = readiness == .active
    }

    private var statusText: String {
        readiness == .active && !tap.isEnabled ? "Orbitile is paused" : readiness.message
    }

    @objc private func toggleEnabled() {
        tap.isEnabled.toggle()
        UserDefaults.standard.set(tap.isEnabled, forKey: Self.enabledKey)
        refreshReadiness()
    }

    @objc private func showAbout() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let credits = NSAttributedString(
            string: "Tile windows with the middle mouse button.\nClick to open, pick a layout, click or drag across cells.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Orbitile",
            .applicationVersion: version,
            .version: "",
            .credits: credits,
        ])
    }

    @objc private func openSettings() {
        if let url = readiness.settingsURL { NSWorkspace.shared.open(url) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshReadiness()
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
    render("ten", family: 4, cell: 6, drag: nil)

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

if let i = CommandLine.arguments.firstIndex(of: "--dmg-background"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { DmgArt.run(into: CommandLine.arguments[i + 1]) }
    exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--scenes"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { Scenes.run(into: CommandLine.arguments[i + 1]) }
    exit(0)
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
