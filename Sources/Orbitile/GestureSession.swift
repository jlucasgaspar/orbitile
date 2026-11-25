import AppKit
import OrbitileCore

/// One press-hold-release gesture, from the middle-button press to apply or cancel.
@MainActor
final class GestureSession {
    private let target: TargetWindow
    private let screen: NSScreen
    /// The fan reopens on the last family used (family 8 the first time), like the design.
    private static var lastFamily = 3
    private let model = FanModel()
    private let panel: OverlayPanel

    /// Captures the window under `point` (global, top-left origin) *before* any overlay exists.
    /// Returns nil when there is no movable window there.
    init?(startingAt point: CGPoint) {
        guard let target = TargetWindow.capture(at: point) else { return nil }
        let appKit = Self.appKitPoint(point)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(appKit) }) ?? NSScreen.main else { return nil }
        self.target = target
        self.screen = screen
        panel = OverlayPanel(screen: screen, model: model)
        model.state = FanState(family: Self.lastFamily)

        let size = screen.frame.size
        model.center = FanGeometry.clampCenter(viewPoint(point), in: CGRect(origin: .zero, size: size))
        panel.show()
        update(to: point)
    }

    enum Press { case cancel, drag, ignore }

    func update(to point: CGPoint) {
        let v = viewPoint(point)
        let rel = CGPoint(x: v.x - model.center.x, y: v.y - model.center.y)
        var state = model.state
        state.update(FanGeometry.hit(rel, expanded: state.family))
        model.state = state
        refreshPreview()
        if let i = state.familyIndex { Self.lastFamily = i }
        NSCursor.arrow.set()
    }

    /// Keyboard 2/4/6/8: jump to a family without moving the pointer.
    func selectFamily(_ index: Int) {
        var state = model.state
        state.select(family: index)
        model.state = state
        Self.lastFamily = index
        refreshPreview()
    }

    /// Left press: a cell starts a drag, outside the disc cancels, the rest is inert.
    func press(at point: CGPoint) -> Press {
        update(to: point)
        let v = viewPoint(point)
        let d = hypot(v.x - model.center.x, v.y - model.center.y)
        if d > FanGeometry.discDiameter / 2 { return .cancel }
        guard model.state.cell != nil else { return .ignore }
        var state = model.state
        state.beginDrag()
        model.state = state
        return .drag
    }

    var isDragging: Bool { model.state.isDragging }

    /// Left release. Returns true when it applied and closed; false when the gesture stays open
    /// (released outside the cells: only the selection clears).
    func release(at point: CGPoint) -> Bool {
        update(to: point)
        guard model.state.span != nil else {
            var state = model.state
            state.endDrag()
            model.state = state
            refreshPreview()
            return false
        }
        finish(apply: true)
        return true
    }

    /// Moves the window only when a cell is hovered. Anything else cancels.
    func finish(apply: Bool) {
        if apply, let s = model.state.span {
            target.move(to: targetFrame(s.family, s.first, s.last), animated: true)
        }
        panel.orderOut(nil)
    }

    private func refreshPreview() {
        model.preview = model.state.span.map { viewRect(targetFrame($0.family, $0.first, $0.last)) }
    }

    private func targetFrame(_ family: LayoutFamily, _ first: Int, _ last: Int) -> CGRect {
        FanGeometry.targetRect(family, from: first, to: last, in: screen.visibleFrame)
    }

    private func viewPoint(_ global: CGPoint) -> CGPoint {
        let a = Self.appKitPoint(global)
        return CGPoint(x: a.x - screen.frame.minX, y: screen.frame.maxY - a.y)
    }

    private func viewRect(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX - screen.frame.minX, y: screen.frame.maxY - r.maxY, width: r.width, height: r.height)
    }

    private static func appKitPoint(_ global: CGPoint) -> CGPoint {
        CGPoint(x: global.x, y: (NSScreen.screens.first?.frame.height ?? 0) - global.y)
    }
}
