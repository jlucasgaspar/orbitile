import AppKit
import ApplicationServices
import OrbitileCore

/// A window captured via Accessibility, held for the whole gesture.
struct TargetWindow {
    let element: AXUIElement

    /// Finds the window under `point` (global coordinates, origin top-left).
    /// Must run before the overlay opens so the fan can never be the target.
    static func capture(at point: CGPoint) -> TargetWindow? {
        let system = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit) == .success,
              let hit else { return nil }
        guard let window = enclosingWindow(of: hit), isMovable(window) else { return nil }
        return TargetWindow(element: window)
    }

    private static func enclosingWindow(of element: AXUIElement) -> AXUIElement? {
        if string(element, kAXRoleAttribute) == kAXWindowRole as String { return element }
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value) == .success,
           let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
            return (value as! AXUIElement)
        }
        return nil
    }

    private static func isMovable(_ window: AXUIElement) -> Bool {
        let subrole = string(window, kAXSubroleAttribute)
        guard subrole == kAXStandardWindowSubrole as String || subrole == kAXDialogSubrole as String else { return false }
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &settable) == .success && settable.boolValue
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    /// Moves the window to `frame` (AppKit coordinates, origin bottom-left).
    func move(to frame: CGRect) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var origin = CGPoint(x: frame.minX, y: primaryHeight - frame.maxY)
        var size = frame.size
        // Size, position, size: avoids clamping when crossing displays.
        set(kAXSizeAttribute, AXValueCreate(.cgSize, &size))
        set(kAXPositionAttribute, AXValueCreate(.cgPoint, &origin))
        set(kAXSizeAttribute, AXValueCreate(.cgSize, &size))
    }

    /// Same as `move(to:)`, eased over 220 ms with cubic-bezier(.2, .8, .2, 1).
    @MainActor
    func move(to frame: CGRect, animated: Bool) {
        guard animated, let from = currentFrame() else { return move(to: frame) }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let to = CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
        let target = self
        Task { @MainActor in
            let duration = 0.22
            let start = Date()
            while true {
                let t = min(1, Date().timeIntervalSince(start) / duration)
                if t >= 1 { break }
                let k = CGFloat(Easing.cubicBezier(0.2, 0.8, 0.2, 1, t))
                target.apply(CGRect(
                    x: from.minX + (to.minX - from.minX) * k, y: from.minY + (to.minY - from.minY) * k,
                    width: from.width + (to.width - from.width) * k, height: from.height + (to.height - from.height) * k))
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            target.move(to: frame)
        }
    }

    /// Current frame, global coordinates with origin top-left.
    private func currentFrame() -> CGRect? {
        var pos: CFTypeRef?, size: CFTypeRef?
        var p = CGPoint.zero, sz = CGSize.zero
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pos) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let pos, let size,
              AXValueGetValue(pos as! AXValue, .cgPoint, &p),
              AXValueGetValue(size as! AXValue, .cgSize, &sz) else { return nil }
        return CGRect(origin: p, size: sz)
    }

    /// One animation step; `frame` is global with origin top-left.
    private func apply(_ frame: CGRect) {
        var origin = frame.origin
        var size = frame.size
        set(kAXSizeAttribute, AXValueCreate(.cgSize, &size))
        set(kAXPositionAttribute, AXValueCreate(.cgPoint, &origin))
    }

    private func set(_ attribute: String, _ value: AXValue?) {
        guard let value else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }
}
