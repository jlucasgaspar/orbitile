import AppKit
import Combine
import OrbitileCore
import SwiftUI

/// Borderless panel that never becomes key or main, so the target app keeps focus.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Real backdrop blur (24 pt class) behind the disc; SwiftUI cannot blur other apps.
    private let blur = NSVisualEffectView()
    private var centerSub: AnyCancellable?

    init(screen: NSScreen, model: FanModel) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let size = screen.frame.size
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        let d = FanGeometry.discDiameter
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        blur.maskImage = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        blur.frame = NSRect(x: 0, y: 0, width: d, height: d)
        blur.isHidden = true
        container.addSubview(blur)
        let host = NSHostingView(rootView: FanView(model: model))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        contentView = container
        centerSub = model.$center.sink { [blur] c in
            guard c != .zero else { return }
            blur.frame = NSRect(x: c.x - d / 2, y: size.height - c.y - d / 2, width: d, height: d)
            blur.isHidden = false
        }
        setFrame(screen.frame, display: false)
    }

    func show() {
        blur.alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            blur.animator().alphaValue = 1
        }
    }
}
